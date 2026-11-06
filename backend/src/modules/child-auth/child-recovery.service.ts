// Kirish maʼlumotlarini tiklash so'rovlari (A03/A04).
//
// Ommaviy so'rov DOIM bir xil `202 { requestId, pollToken }` qaytaradi: login mavjud bo'lmasa "o'lik" so'rov
// (childId = null, hech qachon yechilmaydi) yaratiladi. Ta'sirlar (ota-onaga neytral push, maktab xodimlariga
// saqlangan bildirishnoma, audit) javobdan KEYIN fonda bajariladi — shunda mavjud va mavjud bo'lmagan loginlar
// javob vaqti bo'yicha ham ajralmaydi. Pollda faqat token xeshi solishtiriladi (vaqt bo'yicha xavfsiz).

import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ChildRecoveryRequest, ChildRecoveryChannel } from '@prisma/client';
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { AuditService } from '../../common/audit/audit.service';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { tr } from '../../common/i18n/notification-i18n';
import { errorLabel } from '../../common/notification-prefs/error-label';
import { staffWithPermission } from '../../school/common/staff-recipients';
import { ChildAuthClock } from './child-auth-clock';
import { ChildAuthEffects } from './child-auth-effects';
import {
  CHILD_RECOVERY_NOTIFICATION_KIND,
  CHILD_RECOVERY_PUSH_TYPE,
  childRecoveryNotificationHref,
  childRecoveryNotificationId,
  DAY_MS,
  RECOVERY_EFFECTS_PER_CHILD_PER_DAY,
  RECOVERY_RETENTION_DAYS,
} from './child-auth.constants';
import { requestAlreadyResolved, requestNotFound } from './child-auth.errors';
import { isValidLogin, normalizeLogin } from './child-credentials.helpers';
import { findOwnedChild } from './child-ownership';
import type { ChildRecoveryRequestDto } from './dto/child-recovery.dto';

export interface RecoveryStatusView {
  status: ChildRecoveryRequest['status'];
  /** Bola so'ragan kanal (poll uchun; yetkazish kanali emas). */
  channel: ChildRecoveryChannel;
  createdAt: string;
  restoredAt: string | null;
  signedOutAt: string | null;
}

/** Ota-ona / xodim ko'radigan so'rov (token xeshi hech qachon chiqmaydi). */
export interface RecoveryRequestView {
  id: string;
  channel: ChildRecoveryChannel;
  status: ChildRecoveryRequest['status'];
  createdAt: string;
}

export const toRecoveryView = (
  r: Pick<ChildRecoveryRequest, 'id' | 'channel' | 'status' | 'createdAt'>,
): RecoveryRequestView => ({
  id: r.id,
  channel: r.channel,
  status: r.status,
  createdAt: r.createdAt.toISOString(),
});

interface RecoveryTarget {
  childId: string;
  parentId: string;
  channel: ChildRecoveryChannel;
  /** Maktab kanali uchun: xodim bildirishnomasi mazmuni. */
  school: { schoolId: string; studentId: string; classId: string | null; studentName: string; className: string } | null;
}

/** Mavjud bo'lmagan bola uchun "bir xil sondagi so'rovlar" (vaqt tartibi mos kelsin) — hech narsa topilmaydi. */
const NO_CHILD_ID = '00000000-0000-0000-0000-000000000000';

const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');
/** Poll tokeni topilmagan so'rov uchun ham xuddi shu solishtirish bajariladi. */
const MISSING_HASH = hashToken('child-recovery:missing');

@Injectable()
export class ChildRecoveryService {
  private readonly logger = new Logger(ChildRecoveryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
    private readonly audit: AuditService,
    private readonly clock: ChildAuthClock,
    private readonly effects: ChildAuthEffects,
  ) {}

  // ── Ommaviy ────────────────────────────────────────────────────────

  async request(dto: ChildRecoveryRequestDto): Promise<{ requestId: string; pollToken: string }> {
    const now = this.clock.now();
    const login = normalizeLogin(dto.login);
    // Mavjud va mavjud bo'lmagan (yoki yaroqsiz formatdagi) login bir xil sondagi DB so'rovlari bilan o'tadi:
    // javob vaqti tartibi ham login mavjudligini ko'rsatmasin.
    const target = await this.resolveTarget(isValidLogin(login) ? login : '', dto.channel);
    // Bola uchun sutkadagi ta'sirli so'rovlar soni (throttler restartda nolga tushadi — bu DB asosida).
    const recent = await this.prisma.childRecoveryRequest.count({
      where: { childId: target?.childId ?? NO_CHILD_ID, createdAt: { gte: new Date(now.getTime() - DAY_MS) } },
    });

    const pollToken = randomBytes(32).toString('base64url');
    const row = await this.prisma.childRecoveryRequest.create({
      data: {
        childId: target?.childId ?? null,
        // Samarali kanal (yetkazish va ro'yxatlar uchun) va bola so'ragan kanal (poll uchun) alohida.
        channel: target?.channel ?? dto.channel,
        requestedChannel: dto.channel,
        pollTokenHash: hashToken(pollToken),
        createdAt: now,
      },
      select: { id: true },
    });
    if (target && recent < RECOVERY_EFFECTS_PER_CHILD_PER_DAY) {
      this.effects.track(this.deliver(target, row.id, now), 'tiklash so\'rovi ta\'siri');
    }
    return { requestId: row.id, pollToken };
  }

  async status(requestId: string, token: unknown): Promise<RecoveryStatusView> {
    const row =
      typeof token === 'string' && token.length > 0 && token.length <= 200
        ? await this.prisma.childRecoveryRequest.findUnique({ where: { id: requestId } })
        : null;
    const expected = Buffer.from(row?.pollTokenHash ?? MISSING_HASH, 'hex');
    const given = Buffer.from(hashToken(typeof token === 'string' ? token : ''), 'hex');
    const tokenOk = expected.length === given.length && timingSafeEqual(expected, given);
    if (!row || !tokenOk) throw new NotFoundException({ code: 'NOT_FOUND', message: 'Request not found' });
    return {
      status: row.status,
      // Bola SO'RAGAN kanal: samarali kanal (bola maktabga bog'lanmagan bo'lsa PARENT) login mavjudligini fosh qilardi.
      channel: row.requestedChannel,
      createdAt: row.createdAt.toISOString(),
      restoredAt: row.restoredAt?.toISOString() ?? null,
      signedOutAt: row.signedOutAt?.toISOString() ?? null,
    };
  }

  // ── Ota-ona ────────────────────────────────────────────────────────

  async listForParent(parentId: string, childId: string): Promise<RecoveryRequestView[]> {
    await findOwnedChild(this.prisma, parentId, childId);
    return this.listOpen(childId, 'PARENT');
  }

  async rejectForParent(
    parentId: string,
    childId: string,
    requestId: string,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ): Promise<RecoveryRequestView> {
    await findOwnedChild(this.prisma, parentId, childId);
    const view = await this.reject(childId, requestId, 'PARENT');
    await this.audit.log(parentId, 'child', 'RECOVERY_REJECT', childId, { requestId }, reqMeta);
    return view;
  }

  // ── Maktab (doira va ruxsat tekshiruvi chaqiruvchida) ──────────────

  /** Bolaning ochiq so'rovlari (kanal bo'yicha), eng yangisi birinchi. */
  async listOpen(childId: string, channel: ChildRecoveryChannel): Promise<RecoveryRequestView[]> {
    const rows = await this.prisma.childRecoveryRequest.findMany({
      where: { childId, channel, status: 'RECEIVED' },
      orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
    });
    return rows.map(toRecoveryView);
  }

  /** Ochiq so'rovni rad etadi; xodim bildirishnomasi ham olib tashlanadi. */
  async reject(childId: string, requestId: string, channel: ChildRecoveryChannel): Promise<RecoveryRequestView> {
    const now = this.clock.now();
    return this.prisma.$transaction(async (tx) => {
      const row = await tx.childRecoveryRequest.findFirst({ where: { id: requestId, childId, channel } });
      if (!row) throw requestNotFound();
      if (row.status !== 'RECEIVED') throw requestAlreadyResolved();
      const res = await tx.childRecoveryRequest.updateMany({
        where: { id: row.id, status: 'RECEIVED' },
        data: { status: 'REJECTED', rejectedAt: now },
      });
      if (res.count === 0) throw requestAlreadyResolved();
      await tx.schoolStaffNotification.deleteMany({ where: { id: childRecoveryNotificationId(row.id) } });
      return toRecoveryView({ ...row, status: 'REJECTED' });
    });
  }

  // ── Fon ishlari ────────────────────────────────────────────────────

  /** Fonda ketayotgan ta'sirlar tugashini kutadi (testlar va to'xtatish). */
  async drainEffects(): Promise<void> {
    await this.effects.drain();
  }

  /** Eskirgan so'rovlar (va ularning xodim bildirishnomalari) saqlash muddatidan keyin o'chiriladi. */
  @Cron('0 40 3 * * *', { name: 'child-recovery-retention' })
  async purgeExpired(): Promise<void> {
    try {
      const cutoff = new Date(this.clock.now().getTime() - RECOVERY_RETENTION_DAYS * DAY_MS);
      const old = await this.prisma.childRecoveryRequest.findMany({
        where: { createdAt: { lt: cutoff } },
        select: { id: true },
        take: 5000,
      });
      if (old.length === 0) return;
      const ids = old.map((r) => r.id);
      await this.prisma.$transaction([
        this.prisma.schoolStaffNotification.deleteMany({ where: { id: { in: ids.map(childRecoveryNotificationId) } } }),
        this.prisma.childRecoveryRequest.deleteMany({ where: { id: { in: ids } } }),
      ]);
      this.logger.log(`tiklash so'rovlari: ${ids.length} ta eskirgan so'rov o'chirildi`);
    } catch (err) {
      this.logger.error(`tiklash so'rovlarini tozalash bajarilmadi: ${errorLabel(err)}`);
    }
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /**
   * Login egasi bola va samarali kanal. Maktab kanali faqat bola faol maktab o'quvchisiga bog'langan bo'lsa;
   * aks holda ota-onaga tushadi (bola kutmasdan yo'qolib qolmasin).
   */
  private async resolveTarget(login: string, requested: ChildRecoveryChannel): Promise<RecoveryTarget | null> {
    const cred = await this.prisma.childCredential.findUnique({
      where: { login },
      select: { child: { select: { id: true, parentId: true } } },
    });
    if (!cred) {
      // Parite: mavjud bola uchun maktab qidiruvi bajariladi — mavjud bo'lmaganida ham xuddi shu so'rov.
      if (requested === 'SCHOOL') await this.prisma.schoolStudent.findUnique({ where: { childId: NO_CHILD_ID }, select: { id: true } });
      return null;
    }
    const { id: childId, parentId } = cred.child;
    if (requested === 'SCHOOL') {
      const student = await this.prisma.schoolStudent.findUnique({
        where: { childId },
        select: {
          id: true,
          schoolId: true,
          classId: true,
          archived: true,
          lastName: true,
          firstName: true,
          class: { select: { name: true } },
          school: { select: { status: true } },
        },
      });
      if (student && !student.archived && student.school.status === 'ACTIVE') {
        return {
          childId,
          parentId,
          channel: 'SCHOOL',
          school: {
            schoolId: student.schoolId,
            studentId: student.id,
            classId: student.classId,
            studentName: `${student.lastName} ${student.firstName}`,
            className: student.class?.name ?? '',
          },
        };
      }
    }
    return { childId, parentId, channel: 'PARENT', school: null };
  }

  /** Ta'sirlar: audit + (ota-onaga neytral push | maktab xodimlariga saqlangan bildirishnoma). */
  private async deliver(target: RecoveryTarget, requestId: string, at: Date): Promise<void> {
    await this.safely('audit', () =>
      this.audit.log(null, 'auth', 'CHILD_RECOVERY_REQUEST', target.childId, { channel: target.channel }),
    );
    if (target.school) {
      const school = target.school;
      await this.safely('staff notification', () => this.storeStaffNotification(requestId, school, at));
      return;
    }
    await this.safely('parent push', () => this.pushParent(target));
  }

  /**
   * Maktab xodimlariga saqlangan bildirishnoma: FAQAT ish qila oladiganlarga — o'quvchining maktabidagi FAOL xodimlar,
   * `students.manage` ruxsatiga ega va doirasi shu o'quvchini qamraydi (DIRECTOR, ADMIN; sinf rahbari — agar unga
   * `students.manage` berilgan bo'lsa). Hech kim mos kelmasa — direktor(lar)ga. Oluvchilar `staffIds`da, ularning
   * rollari `roles`da (panel lentasi ikkala shartni ham tekshiradi).
   */
  private async storeStaffNotification(
    requestId: string,
    school: NonNullable<RecoveryTarget['school']>,
    at: Date,
  ): Promise<void> {
    const recipients = await staffWithPermission(this.prisma, school.schoolId, 'students.manage', school.classId);
    const id = childRecoveryNotificationId(requestId);
    const data = {
      schoolId: school.schoolId,
      kind: CHILD_RECOVERY_NOTIFICATION_KIND,
      at,
      roles: recipients.length > 0 ? [...new Set(recipients.map((r) => r.role))] : ['DIRECTOR'],
      classIds: school.classId ? [school.classId] : [],
      staffIds: recipients.map((r) => r.id),
      params: { studentName: school.studentName, className: school.className },
      // Bir xil ismli o'quvchilar adashmasin: panel aynan shu o'quvchining «Kirish» bo'limini ochadi.
      href: childRecoveryNotificationHref(school.studentId),
    };
    await this.prisma.schoolStaffNotification.upsert({ where: { id }, create: { id, ...data }, update: data });
  }

  /** Neytral push: bola ismi yo'q; `data.childId` orqali ilova kerakli bolani ochadi. */
  private async pushParent(target: RecoveryTarget): Promise<void> {
    const lang = await this.fcm.getUserLang(target.parentId);
    await this.fcm.sendPushToUser(target.parentId, {
      title: tr(lang, 'push.neutralTitle'),
      body: tr(lang, 'childRecovery.body'),
      data: { type: CHILD_RECOVERY_PUSH_TYPE, childId: target.childId },
    });
  }

  private async safely(step: string, run: () => Promise<unknown>): Promise<void> {
    try {
      await run();
    } catch (err) {
      this.logger.warn(`tiklash so'rovi: ${step} bajarilmadi: ${errorLabel(err)}`);
    }
  }
}
