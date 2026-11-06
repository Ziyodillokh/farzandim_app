// Bola ovozi eskalatsiyasi (har 5 daqiqada, Toshkent). Qoida: murojaat HALI OCHILMAGAN
// (`openedAt = null`), `NEW`, avval o'tkazilmagan va ish vaqtidagi muddati o'tgan bo'lsa —
// maktabda o'rinbosar sozlangan bo'lsa murojaat unga o'tadi (`assignedStaffId`, `escalatedAt`),
// o'rinbosarga saqlangan bildirishnoma (shoshilinch bo'lsa direktorga ham, ismsiz signal).
// Muddat: shoshilinch — `urgentSlaMinutes`, oddiy — `normalSlaHours` ISH VAQTI (dam olish
// kunlari, bayramlar va ish soatlaridan tashqari vaqt hisobga olinmaydi).
// Eski navbat o'tkazilmaydi: o'rinbosar sozlanganda butun eski `NEW` murojaatlar birdaniga ko'chib
// ketmasin — faqat maktab sozlamalari qatori birinchi yaratilgandan KEYIN yaratilgan murojaatlar
// ko'rib chiqiladi (`SchoolCareSettings.createdAt`).
// Idempotent: shartli UPDATE bir murojaatni ikki marta (parallel nusxalarda ham) o'tkazmaydi.

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { SchoolCareRequest } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { TASHKENT_TZ, tashkentDay } from '../../common/time/tashkent';
import { SchoolAuditService } from '../common/school-audit.service';
import { CareNotifyService } from './care-notify.service';
import { hoursOf, slaMinutes } from './care-settings';
import { CareSettingsService } from './care-settings.service';
import { addWorkingMinutes } from './care-working-time';

/** Bir ishga tushirishda ko'pi bilan shuncha murojaat ko'rib chiqiladi (qolgani keyingi safar). */
const SWEEP_BATCH = 500;

@Injectable()
export class CareEscalationCron {
  private readonly logger = new Logger(CareEscalationCron.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly settings: CareSettingsService,
    private readonly notify: CareNotifyService,
    private readonly audit: SchoolAuditService,
  ) {}

  @Cron('0 */5 * * * *', { name: 'school-care-escalation', timeZone: TASHKENT_TZ })
  async handleCron(): Promise<void> {
    try {
      const escalated = await this.sweep(new Date());
      if (escalated > 0) this.logger.log(`bola ovozi eskalatsiyasi: ${escalated} murojaat o'rinbosarga o'tdi`);
    } catch (err) {
      this.logger.error(`bola ovozi eskalatsiya cron xatosi: ${err instanceof Error ? err.message : 'noma\'lum'}`);
    }
  }

  /** O'tkazilgan murojaatlar soni. */
  async sweep(now: Date = new Date()): Promise<number> {
    const configured = await this.prisma.schoolCareSettings.findMany({
      where: { deputyStaffId: { not: null }, school: { status: 'ACTIVE' } },
      select: { schoolId: true, createdAt: true },
    });
    let total = 0;
    for (const { schoolId, createdAt } of configured) total += await this.sweepSchool(schoolId, createdAt, now);
    return total;
  }

  private async sweepSchool(schoolId: string, configuredAt: Date, now: Date): Promise<number> {
    const candidates = await this.prisma.schoolCareRequest.findMany({
      where: { schoolId, status: 'NEW', openedAt: null, escalatedAt: null, createdAt: { gte: configuredAt } },
      orderBy: { createdAt: 'asc' },
      take: SWEEP_BATCH,
    });
    if (candidates.length === 0) return 0;
    const state = await this.settings.load(schoolId);
    const deputyId = await this.settings.activeDeputyId(schoolId, state);
    if (!deputyId) return 0;
    const oldest = candidates[0]!.createdAt;
    const holidays = await this.settings.holidays(schoolId, tashkentDay(oldest));
    const hours = hoursOf(state.settings);
    let escalated = 0;
    for (const request of candidates) {
      const deadline = addWorkingMinutes(request.createdAt, slaMinutes(state.settings, request.urgency), hours, holidays);
      if (!deadline || deadline.getTime() > now.getTime()) continue;
      if (await this.escalate(request, deputyId, now)) escalated += 1;
    }
    return escalated;
  }

  /** Shartli UPDATE: shu orada xodim ochgan / javob bergan yoki boshqa nusxa o'tkazgan bo'lsa — hech narsa. */
  private async escalate(request: SchoolCareRequest, deputyId: string, now: Date): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      const res = await tx.schoolCareRequest.updateMany({
        where: { id: request.id, status: 'NEW', openedAt: null, escalatedAt: null },
        data: { assignedStaffId: deputyId, escalatedAt: now },
      });
      if (res.count === 0) return false;
      const cls = request.classId ? await tx.schoolClass.findFirst({ where: { id: request.classId, schoolId: request.schoolId }, select: { name: true } }) : null;
      await this.notify.escalated(tx, request, deputyId, cls?.name ?? '', now);
      await this.audit.writeExternal(request.schoolId, 'Tizim', {
        module: 'CARE',
        action: 'care.request.escalate',
        summary: 'Bola ovozi: murojaat muddatida ochilmadi, o\'rinbosarga o\'tkazildi',
      }, tx);
      return true;
    });
  }
}
