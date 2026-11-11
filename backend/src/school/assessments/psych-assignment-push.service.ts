// Mutaxassis test tayinlaganda bolalarga push. Darhol ochiq tayinlash — tayinlash paytida; kelajakda
// ochiladigani — ochilish vaqtidan keyingi birinchi cron'da (har 5 daqiqa; tunda 22:00–07:00 yuborilmaydi,
// ertalab yuboriladi). Har (tayinlash, bola) uchun BIR marta; xato tayinlashni hech qachon yiqitmaydi.

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../common/database/prisma.service';
import { errorLabel } from '../../common/notification-prefs/error-label';
import { TASHKENT_OFFSET_MS, TASHKENT_TZ, tashkentDay } from '../../common/time/tashkent';
import { SchoolChildPushService } from '../common/school-child-push.service';
import { PARVOZ_IQ_TEST_ID } from './assessments-iq.service';
import {
  assignmentRecipientsWhere,
  isOpenNow,
  PSYCH_ASSIGNMENT_DEDUPE_KIND,
  psychAssignmentPush,
  selectPsychRecipients,
} from './psych-assignment-push';

/** Cron shuncha vaqt ichida ochilgan tayinlashlarni ko'radi (tungi tanaffusdan keyin ham ulgurish uchun). */
const SWEEP_WINDOW_MS = 12 * 60 * 60 * 1000;
/** Shundan kechroq ochilish "rejalashtirilgan" hisoblanadi (aks holda push tayinlashda ketgan). */
const SCHEDULED_AFTER_MS = 60 * 1000;
/** Bir ishga tushirishda ko'pi bilan shuncha tayinlash. */
const SWEEP_BATCH = 200;
/** Toshkent vaqti: shu soatdan ... */
const QUIET_FROM_HOUR = 22;
/** ... shu soatgacha cron push yubormaydi. */
const QUIET_TO_HOUR = 7;

const tashkentHour = (at: Date): number => new Date(at.getTime() + TASHKENT_OFFSET_MS).getUTCHours();

export const isQuietHour = (at: Date): boolean => {
  const hour = tashkentHour(at);
  return hour >= QUIET_FROM_HOUR || hour < QUIET_TO_HOUR;
};

@Injectable()
export class PsychAssignmentPushService {
  private readonly logger = new Logger(PsychAssignmentPushService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: SchoolChildPushService,
  ) {}

  /** Hozir ochiq tayinlashni ko'radigan bolalarga push; qaytadi — FCM qabul qilganlar soni. */
  async notify(assignmentId: string, now: Date = new Date()): Promise<number> {
    try {
      const a = await this.prisma.schoolPsychAssignment.findUnique({ where: { id: assignmentId } });
      if (!a || !isOpenNow(a, now)) return 0;
      const where = assignmentRecipientsWhere(a);
      if (!where) return 0;
      const rows = await this.prisma.schoolStudent.findMany({
        where,
        select: { childId: true, child: { select: { childUserId: true, birthDate: true, age: true } } },
      });
      const iq = a.testId === PARVOZ_IQ_TEST_ID;
      const recipients = selectPsychRecipients(rows, { iq, day: tashkentDay(now) });
      return await this.push.sendOnce(recipients, PSYCH_ASSIGNMENT_DEDUPE_KIND, a.id, (lang) =>
        psychAssignmentPush(lang, { id: a.id, iq }),
      );
    } catch (err) {
      this.logger.error(`test tayinlash push xatosi: ${errorLabel(err)}`);
      return 0;
    }
  }

  @Cron('0 */5 * * * *', { name: 'school-psych-assignment-push', timeZone: TASHKENT_TZ })
  async handleCron(): Promise<void> {
    try {
      const delivered = await this.sweep(new Date());
      if (delivered > 0) this.logger.log(`rejalashtirilgan testlar: ${delivered} bolaga push`);
    } catch (err) {
      this.logger.error(`test tayinlash push cron xatosi: ${errorLabel(err)}`);
    }
  }

  /** Rejalashtirilgan (keyinroq ochilgan) tayinlashlar; qaytadi — FCM qabul qilganlar soni. */
  async sweep(now: Date): Promise<number> {
    if (isQuietHour(now)) return 0;
    const opened = await this.prisma.schoolPsychAssignment.findMany({
      where: {
        status: 'OPEN',
        opensAt: { gte: new Date(now.getTime() - SWEEP_WINDOW_MS), lte: now },
        closesAt: { gte: now },
      },
      select: { id: true, createdAt: true, opensAt: true },
      orderBy: { opensAt: 'asc' },
      take: SWEEP_BATCH,
    });
    const scheduled = opened.filter((a) => a.opensAt.getTime() - a.createdAt.getTime() > SCHEDULED_AFTER_MS);
    let delivered = 0;
    for (const a of scheduled) delivered += await this.notify(a.id, now);
    return delivered;
  }
}
