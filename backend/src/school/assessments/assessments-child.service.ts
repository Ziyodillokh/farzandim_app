// Parvoz Growth bola ilovasi ↔ psixologik testlar: ochiq tayinlashlar, test
// (to'g'ri javoblarsiz, bola tilida) va javob yuborish. Server baholaydi, xom
// ballar va SHIFRLANGAN javoblar bir marta saqlanadi; bolaga ball qaytarilmaydi
// (skrining natijasi psixolog uchun). Psixologga "test yakunlandi" bildirishnomasi
// — bola ismisiz, faqat son.

import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, SchoolPsychAssignment } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay, tashkentDayRange } from '../../common/time/tashkent';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { parseOrThrow } from '../common/school-zod';
import { submitInputSchema } from './assessments-inputs.schemas';
import { AssessmentsStore } from './assessments-store';
import { ChildLang, childLang, pick, toAnswerVector, toChildTest } from './child-view';
import { ageBandOf, ageOn, encodeAnswers, rawScores } from './psych/scoring';
import type { PsychTest } from './psych/types';

type Tx = Prisma.TransactionClient;
type Student = { id: string; schoolId: string; classId: string; grade: number; birthDate: string; lang: ChildLang };

/** Yopilish vaqtidan keyin topshirish uchun qo'shimcha vaqt (test vaqt chegarasi, bo'lmasa 30 daqiqa). */
const DEFAULT_GRACE_MIN = 30;
const MINUTE_MS = 60_000;

const notEnrolled = () => new NotFoundException({ code: 'NOT_ENROLLED', message: 'Child is not linked to a school' });
const notOpen = () => new NotFoundException({ code: 'ASSIGNMENT_NOT_FOUND', message: 'Assignment is not open' });
const alreadySubmitted = () => new ConflictException({ code: 'ALREADY_SUBMITTED', message: 'Test already submitted' });

const isOpenAt = (a: Pick<SchoolPsychAssignment, 'opensAt' | 'closesAt'>, nowMs: number, graceMs = 0) =>
  a.opensAt.getTime() <= nowMs && nowMs <= a.closesAt.getTime() + graceMs;

/** "N ta o'quvchi testni yakunladi" — har tayinlash uchun kuniga bitta (yangilanadi). */
export const testCompletedId = (assignmentId: string, day: string) => `ntf-test-${assignmentId}-${day}`;

@Injectable()
export class AssessmentsChildService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: AssessmentsStore,
    private readonly crypto: SchoolCryptoService,
  ) {}

  /** Bolaning sinfiga ochiq, hali yechilmagan tayinlashlar (opensAt ≤ hozir ≤ closesAt). */
  async openAssignments(childUserId: string) {
    const student = await this.student(childUserId);
    if (!student) return { enrolled: false, assignments: [] };
    const nowMs = Date.now();
    const now = new Date(nowMs);
    const rows = await this.prisma.schoolPsychAssignment.findMany({
      where: { schoolId: student.schoolId, status: 'OPEN', classIds: { has: student.classId }, opensAt: { lte: now }, closesAt: { gte: now } },
      orderBy: [{ closesAt: 'asc' }, { createdAt: 'asc' }],
    });
    const done = await this.prisma.schoolPsychResult.findMany({
      where: { schoolId: student.schoolId, studentId: student.id, assignmentId: { in: rows.map((r) => r.id) } },
      select: { assignmentId: true },
    });
    const doneIds = new Set(done.map((d) => d.assignmentId));
    const assignments = [];
    for (const a of rows.filter((r) => !doneIds.has(r.id))) {
      const test = await this.store.findTest(student.schoolId, a.testId);
      if (!test || test.items.length === 0) continue;
      assignments.push({
        assignmentId: a.id,
        testId: test.id,
        kind: test.kind,
        title: pick(test.title, student.lang),
        description: pick(test.description, student.lang),
        itemCount: test.items.length,
        timeLimitMin: test.timeLimitMin,
        closesAt: a.closesAt.toISOString(),
      });
    }
    return { enrolled: true, assignments };
  }

  /** Test savollari — to'g'ri javoblar va shkalalarsiz, bola tilida. */
  async assignment(childUserId: string, assignmentId: string) {
    const student = await this.student(childUserId);
    if (!student) throw notEnrolled();
    const { assignment, test } = await this.openFor(this.prisma, student, assignmentId, 0);
    if (await this.submitted(this.prisma, assignment.id, student.id)) throw alreadySubmitted();
    return { assignmentId: assignment.id, closesAt: assignment.closesAt.toISOString(), ...toChildTest(test, student.lang) };
  }

  async submit(childUserId: string, assignmentId: string, body: unknown): Promise<{ ok: true }> {
    const student = await this.student(childUserId);
    if (!student) throw notEnrolled();
    const input = parseOrThrow(submitInputSchema, body ?? {});
    await this.prisma.$transaction(async (tx) => {
      // Bitta tayinlash bo'yicha navbat: takroriy yuborish va bildirishnoma soni aniq.
      await this.store.lock(tx, `psych-assignment:${assignmentId}`);
      const { assignment, test } = await this.openFor(tx, student, assignmentId, graceMs);
      if (await this.submitted(tx, assignment.id, student.id)) throw alreadySubmitted();
      const vector = toAnswerVector(test, input.answers);
      const now = new Date();
      await tx.schoolPsychResult.create({
        data: {
          schoolId: student.schoolId,
          studentId: student.id,
          classId: student.classId,
          grade: student.grade,
          ageBand: ageBandOf(ageOn(student.birthDate, tashkentDay(now))),
          testId: test.id,
          version: test.version,
          assignmentId: assignment.id,
          takenAt: now,
          origin: 'APP',
          raw: rawScores(test, vector),
          answersEnc: this.crypto.encrypt(encodeAnswers(test, vector)),
          durationSec: input.durationSec ?? null,
        },
      });
      await this.notifyCompleted(tx, student.schoolId, assignment, test, now);
    });
    return { ok: true };
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /** Bolaning sinfiga tayinlangan, OPEN va vaqt oynasidagi tayinlash + testi; aks holda 404. */
  private async openFor(db: Tx | PrismaService, student: Student, assignmentId: string, grace: number | ((test: PsychTest) => number)) {
    const assignment = await db.schoolPsychAssignment.findFirst({
      where: { id: assignmentId, schoolId: student.schoolId, status: 'OPEN', classIds: { has: student.classId } },
    });
    if (!assignment) throw notOpen();
    const test = await this.store.findTest(student.schoolId, assignment.testId, db);
    if (!test || test.items.length === 0) throw notOpen();
    const graceMs = typeof grace === 'function' ? grace(test) : grace;
    if (!isOpenAt(assignment, Date.now(), graceMs)) throw notOpen();
    return { assignment, test };
  }

  private async submitted(db: Tx | PrismaService, assignmentId: string, studentId: string): Promise<boolean> {
    return (await db.schoolPsychResult.count({ where: { assignmentId, studentId } })) > 0;
  }

  private async notifyCompleted(tx: Tx, schoolId: string, a: SchoolPsychAssignment, test: PsychTest, now: Date): Promise<void> {
    const day = tashkentDay(now);
    const count = await tx.schoolPsychResult.count({ where: { schoolId, assignmentId: a.id, takenAt: tashkentDayRange(day) } });
    const id = testCompletedId(a.id, day);
    const subject = test.title as unknown as Prisma.InputJsonValue;
    await tx.schoolStaffNotification.upsert({
      where: { id },
      create: {
        id,
        schoolId,
        kind: 'TEST_COMPLETED',
        at: now,
        roles: ['PSYCHOLOGIST'],
        classIds: [],
        params: { count },
        subject,
        href: `/assessments?tab=results&test=${a.testId}`,
      },
      update: { at: now, params: { count }, subject },
    });
  }

  private async student(childUserId: string): Promise<Student | null> {
    const child = await this.prisma.child.findUnique({
      where: { childUserId },
      select: { id: true, childUser: { select: { language: true } } },
    });
    if (!child) return null;
    const s = await this.prisma.schoolStudent.findUnique({
      where: { childId: child.id },
      select: { id: true, schoolId: true, classId: true, archived: true, birthDate: true, class: { select: { grade: true } }, school: { select: { status: true } } },
    });
    if (!s || s.archived || !s.classId || !s.class || s.school.status !== 'ACTIVE') return null;
    return { id: s.id, schoolId: s.schoolId, classId: s.classId, grade: s.class.grade, birthDate: s.birthDate, lang: childLang(child.childUser?.language) };
  }
}

/** Yopilgandan keyin topshirish uchun qo'shimcha vaqt: test vaqti chegarasi (bo'lmasa 30 daqiqa). */
function graceMs(test: PsychTest): number {
  return (test.timeLimitMin ?? DEFAULT_GRACE_MIN) * MINUTE_MS;
}
