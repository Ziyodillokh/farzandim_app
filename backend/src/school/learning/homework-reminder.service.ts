// Ertangi topshiriq eslatmasi (Men I07): har kuni 17:00 (Toshkent) — muddati ERTAGA bo'lgan va hali
// bajarilmagan/topshirilmagan maktab topshirig'i bor bolaga bitta neytral push ("Ertaga topshiriq muddati").
// Soat 17:00, 17:15 va 17:30 da ishlaydi (server qayta ishga tushsa ham o'tkazib yubormaydi); har bola kuniga
// BIR marta (`child_push_dedupe` yagona qatori). Push xatosi hech narsani yiqitmaydi; logda bola/topshiriq ma'lumoti yo'q.

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { mapLimit } from '../../common/helpers/map-limit';
import { tr } from '../../common/i18n/notification-i18n';
import { ChildPushDedupeService } from '../../common/notification-prefs/child-push-dedupe.service';
import { errorLabel } from '../../common/notification-prefs/error-label';
import { isQuietAt, tashkentMinutesOfDay } from '../../common/notification-prefs/notification-prefs';
import { addDays, TASHKENT_TZ, tashkentDay } from '../../common/time/tashkent';
import {
  childrenWithPendingTomorrow,
  handInKey,
  ReminderAssignment,
  ReminderStudent,
} from './homework-reminder';
import { testSubjectOf } from './school-learning-catalog';
import { WRITTEN_KIND } from './school-learning.schemas';

/** `child_push_dedupe.kind` — kalit: eslatma kuni (`YYYY-MM-DD`). */
export const HOMEWORK_DUE_KIND = 'HOMEWORK_DUE';
export const HOMEWORK_DUE_PUSH_TYPE = 'HOMEWORK_DUE';
const PUSH_CONCURRENCY = 8;

/** Topshiriqlar maktab bo'yicha (har maktab alohida so'rovlar bilan qayta ishlanadi). */
function groupBySchool(assignments: readonly ReminderAssignment[]): ReminderAssignment[][] {
  const groups = new Map<string, ReminderAssignment[]>();
  for (const a of assignments) groups.set(a.schoolId, [...(groups.get(a.schoolId) ?? []), a]);
  return [...groups.values()];
}

interface Recipient {
  childId: string;
  childUserId: string;
}

@Injectable()
export class HomeworkReminderService {
  private readonly logger = new Logger(HomeworkReminderService.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
    private readonly dedupe: ChildPushDedupeService,
  ) {}

  @Cron('0 0,15,30 17 * * *', { name: 'school-homework-reminder', timeZone: TASHKENT_TZ })
  async tick(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const sent = await this.remindDue(new Date());
      if (sent > 0) this.logger.log(`uy vazifasi eslatmasi: ${sent} ta push`);
    } catch (err) {
      this.logger.error(`uy vazifasi eslatmasi xatosi: ${errorLabel(err)}`);
    } finally {
      this.running = false;
    }
  }

  /** `now` (Toshkent kuni) uchun: ertaga muddatli topshirig'i bor bolalarga eslatma; yuborilgan push soni. */
  async remindDue(now: Date): Promise<number> {
    const today = tashkentDay(now);
    const tomorrow = addDays(today, 1);
    const assignments = await this.prisma.schoolLearningAssignment.findMany({
      where: { dueDate: tomorrow, school: { status: 'ACTIVE' } },
      select: { id: true, schoolId: true, classIds: true, materialKind: true, materialId: true, dueDate: true, createdAt: true },
    });
    let sent = 0;
    if (assignments.length > 0) {
      for (const list of groupBySchool(assignments)) {
        sent += await this.remindSchool(list, { today, tomorrow, now });
      }
    }
    await this.pruneDedupe(now);
    return sent;
  }

  private async remindSchool(
    assignments: readonly ReminderAssignment[],
    ctx: { today: string; tomorrow: string; now: Date },
  ): Promise<number> {
    const students = await this.eligibleStudents(assignments, ctx.now);
    if (students.length === 0) return 0;
    const pending = childrenWithPendingTomorrow({
      today: ctx.today,
      tomorrow: ctx.tomorrow,
      assignments,
      students,
      handedIn: await this.handedIn(assignments, students),
      attempts: await this.completedAttempts(assignments, students),
    });
    if (pending.size === 0) return 0;
    const recipients = new Map(students.map((s) => [s.childId, s.childUserId]));
    const claimed = await this.dedupe.claim([...pending], HOMEWORK_DUE_KIND, ctx.today);
    const targets = claimed.flatMap((childId): Recipient[] => {
      const childUserId = recipients.get(childId);
      return childUserId ? [{ childId, childUserId }] : [];
    });
    const results = await mapLimit(targets, PUSH_CONCURRENCY, (t) => this.push(t.childUserId));
    return results.filter(Boolean).length;
  }

  /** Maktabdagi (faol, sinfi bor, bola ilovasi ulangan) o'quvchilar; eslatmasi o'chirilgan / tinch soatdagilar chiqarib tashlanadi. */
  private async eligibleStudents(
    assignments: readonly ReminderAssignment[],
    now: Date,
  ): Promise<Array<ReminderStudent & { childUserId: string }>> {
    const classIds = [...new Set(assignments.flatMap((a) => a.classIds))];
    const rows = await this.prisma.schoolStudent.findMany({
      where: {
        schoolId: assignments[0]!.schoolId,
        archived: false,
        classId: { in: classIds },
        childId: { not: null },
        child: { childUserId: { not: null } },
      },
      select: {
        id: true,
        schoolId: true,
        classId: true,
        childId: true,
        child: {
          select: { childUserId: true, notificationPreference: { select: { homeworkReminder: true, quietFrom: true, quietTo: true } } },
        },
      },
    });
    const minutes = tashkentMinutesOfDay(now);
    return rows.flatMap((r) => {
      const pref = r.child?.notificationPreference;
      const childUserId = r.child?.childUserId;
      if (!r.childId || !r.classId || !childUserId) return [];
      if (pref && (!pref.homeworkReminder || isQuietAt(pref.quietFrom, pref.quietTo, minutes))) return [];
      return [{ studentId: r.id, childId: r.childId, schoolId: r.schoolId, classId: r.classId, childUserId }];
    });
  }

  private async handedIn(assignments: readonly ReminderAssignment[], students: readonly ReminderStudent[]): Promise<Set<string>> {
    const writtenIds = assignments.filter((a) => a.materialKind === WRITTEN_KIND).map((a) => a.id);
    if (writtenIds.length === 0) return new Set();
    const rows = await this.prisma.schoolHomeworkSubmission.findMany({
      where: {
        assignmentId: { in: writtenIds },
        studentId: { in: students.map((s) => s.studentId) },
        status: { in: ['SUBMITTED', 'ACCEPTED'] },
      },
      select: { assignmentId: true, studentId: true },
    });
    return new Set(rows.map((r) => handInKey(r.assignmentId, r.studentId)));
  }

  private async completedAttempts(assignments: readonly ReminderAssignment[], students: readonly ReminderStudent[]) {
    const tests = assignments.flatMap((a) => {
      const subject = testSubjectOf(a.materialId);
      return a.materialKind !== WRITTEN_KIND && subject ? [{ subject, createdAt: a.createdAt }] : [];
    });
    if (tests.length === 0) return [];
    const since = new Date(Math.min(...tests.map((t) => t.createdAt.getTime())));
    const rows = await this.prisma.learningAttempt.findMany({
      where: {
        childId: { in: students.map((s) => s.childId) },
        subject: { in: [...new Set(tests.map((t) => t.subject))] },
        status: 'COMPLETED',
        completedAt: { gte: since },
      },
      select: { childId: true, subject: true, completedAt: true },
    });
    return rows.flatMap((r) => (r.completedAt ? [{ childId: r.childId, subject: r.subject, completedAt: r.completedAt }] : []));
  }

  /** Bitta bolaga neytral push; `true` — FCM qabul qildi. Token yo'q yoki xato — jim. */
  private async push(childUserId: string): Promise<boolean> {
    try {
      const lang = await this.fcm.getUserLang(childUserId);
      const result = await this.fcm.sendPushToUser(childUserId, {
        title: tr(lang, 'push.neutralTitle'),
        body: tr(lang, 'homeworkDue.body'),
        data: { type: HOMEWORK_DUE_PUSH_TYPE },
      });
      return result.sent > 0;
    } catch (err) {
      this.logger.warn(`uy vazifasi push yuborilmadi: ${errorLabel(err)}`);
      return false;
    }
  }

  private async pruneDedupe(now: Date): Promise<void> {
    try {
      await this.dedupe.prune(now);
    } catch (err) {
      this.logger.warn(`dedupe tozalash xatosi: ${errorLabel(err)}`);
    }
  }
}
