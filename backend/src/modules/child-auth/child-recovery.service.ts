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
import { ChildAuthClock } from './child-auth-clock';
import {
  CHILD_RECOVERY_NOTIFICATION_KIND,
  CHILD_RECOVERY_PUSH_TYPE,
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
  school: { schoolId: string; classId: string | null; studentName: string; className: string } | null;
}

const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');
/** Poll tokeni topilmagan so'rov uchun ham xuddi shu solishtirish bajariladi. */
const MISSING_HASH = hashToken('child-recovery:missing');

@Injectable()
export class ChildRecoveryService {
  private readonly logger = new Logger(ChildRecoveryService.name);
  private readonly effects = new Set<Promise<void>>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
    private readonly audit: AuditService,
    private readonly clock: ChildAuthClock,
  ) {}

  // ── Ommaviy ────────────────────────────────────────────────────────

  async request(dto: ChildRecoveryRequestDto): Promise<{ requestId: string; pollToken: string }> {
    const now = this.clock.now();
    const login = normalizeLogin(dto.login);
    const target = isValidLogin(login) ? await this.resolveTarget(login, dto.channel) : null;
    // Bola uchun sutkadagi ta'sirli so'rovlar soni (throttler restartda nolga tushadi — bu DB asosida).
    const recent = target
      ? await this.prisma.childRecoveryRequest.count({
          where: { childId: target.childId, createdAt: { gte: new Date(now.getTime() - DAY_MS) } },
        })
      : 0;

    const pollToken = randomBytes(32).toString('base64url');
    const row = await this.prisma.childRecoveryRequest.create({
      data: {
        childId: target?.childId ?? null,
        channel: target?.channel ?? dto.channel,
        pollTokenHash: hashToken(pollToken),
        createdAt: now,
      },
      select: { id: true },
    });
    if (target && recent < RECOVERY_EFFECTS_PER_CHILD_PER_DAY) {
      this.track(this.deliver(target, row.id, now));
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
      channel: row.channel,
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
    await Promise.allSettled([...this.effects]);
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
    if (!cred) return null;
    const { id: childId, parentId } = cred.child;
    if (requested === 'SCHOOL') {
      const student = await this.prisma.schoolStudent.findUnique({
        where: { childId },
        select: {
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

  /** Sinf rahbari (shu sinf) + administrator; sinfsiz o'quvchi uchun faqat administrator. */
  private async storeStaffNotification(
    requestId: string,
    school: NonNullable<RecoveryTarget['school']>,
    at: Date,
  ): Promise<void> {
    const id = childRecoveryNotificationId(requestId);
    const data = {
      schoolId: school.schoolId,
      kind: CHILD_RECOVERY_NOTIFICATION_KIND,
      at,
      roles: school.classId ? ['HOMEROOM', 'ADMIN'] : ['ADMIN'],
      classIds: school.classId ? [school.classId] : [],
      staffIds: [],
      params: { studentName: school.studentName, className: school.className },
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

  private track(work: Promise<void>): void {
    const tracked: Promise<void> = work
      .catch((err) => this.logger.warn(`tiklash so'rovi: ta'sir bajarilmadi: ${errorLabel(err)}`))
      .finally(() => this.effects.delete(tracked));
    this.effects.add(tracked);
  }
}
