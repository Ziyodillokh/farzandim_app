// Parvoz Growth bola ilovasi: o'z sinfiga berilgan maktab topshiriqlari.
// Test topshirig'i shu fan bo'yicha topshiriq berilgandan keyin yakunlangan
// kunlik test bilan "bajarildi" hisoblanadi. Yozma vazifa (WRITTEN) — rasm
// topshiriladi, o'qituvchi QABUL qilgandagina "bajarildi".

import { Injectable } from '@nestjs/common';
import { SchoolLearningAssignment } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { toSubmissionSummary } from '../homework/homework-view';
import { childAssignmentWhere } from './assignment-visibility';
import { loadCatalog, Material, testSubjectOf } from './school-learning-catalog';
import { WRITTEN_KIND } from './school-learning.schemas';

type SubmissionSummary = ReturnType<typeof toSubmissionSummary>;

@Injectable()
export class SchoolLearningChildService {
  constructor(private readonly prisma: PrismaService) {}

  async assignments(childUserId: string) {
    const child = await this.prisma.child.findUnique({ where: { childUserId }, select: { id: true } });
    const student = child
      ? await this.prisma.schoolStudent.findUnique({
          where: { childId: child.id },
          select: { id: true, schoolId: true, classId: true, archived: true, school: { select: { status: true } } },
        })
      : null;
    if (!child || !student || student.archived || !student.classId || student.school.status !== 'ACTIVE') return [];
    const today = tashkentDay();
    const [rows, catalog] = await Promise.all([
      this.prisma.schoolLearningAssignment.findMany({
        where: childAssignmentWhere({ schoolId: student.schoolId, classId: student.classId }, today),
        orderBy: { dueDate: 'asc' },
      }),
      loadCatalog(this.prisma),
    ]);
    const material = new Map(catalog.map((m) => [m.id, m]));
    const [teachers, submissions] = await Promise.all([
      this.teacherNames(student.schoolId, rows),
      this.submissionSummaries(student.id, rows),
    ]);
    return Promise.all(
      rows.map(async (a) => {
        const written = a.materialKind === WRITTEN_KIND;
        const m = material.get(a.materialId);
        const subject = testSubjectOf(a.materialId);
        const submission = written ? (submissions.get(a.id) ?? null) : null;
        const done = written
          ? submission?.status === 'ACCEPTED'
          : subject
            ? (await this.prisma.learningAttempt.count({
                where: { childId: child.id, subject, status: 'COMPLETED', completedAt: { gte: a.createdAt } },
              })) > 0
            : null;
        return {
          id: a.id,
          kind: written ? WRITTEN_KIND : (m?.kind ?? a.materialKind),
          materialKind: written ? WRITTEN_KIND : (m?.kind ?? a.materialKind),
          materialId: a.materialId,
          title: titleOf(a, m),
          estimatedMinutes: a.estimatedMinutes,
          teacherName: teachers.get(a.byStaffId) ?? null,
          subject,
          dueDate: a.dueDate,
          note: a.note,
          overdue: a.dueDate < today,
          done,
          submission,
        };
      }),
    );
  }

  private async teacherNames(schoolId: string, rows: readonly SchoolLearningAssignment[]) {
    const ids = [...new Set(rows.map((r) => r.byStaffId))];
    if (ids.length === 0) return new Map<string, string>();
    const staff = await this.prisma.schoolStaff.findMany({ where: { schoolId, id: { in: ids } }, select: { id: true, fullName: true } });
    return new Map(staff.map((s) => [s.id, s.fullName]));
  }

  /** Yozma vazifalar bo'yicha o'quvchining topshiriqlari (rasm soni bilan). */
  private async submissionSummaries(studentId: string, rows: readonly SchoolLearningAssignment[]) {
    const writtenIds = rows.filter((r) => r.materialKind === WRITTEN_KIND).map((r) => r.id);
    if (writtenIds.length === 0) return new Map<string, SubmissionSummary>();
    const found = await this.prisma.schoolHomeworkSubmission.findMany({
      where: { studentId, assignmentId: { in: writtenIds } },
      include: { _count: { select: { photos: true } } },
    });
    return new Map(found.map((s) => [s.assignmentId, toSubmissionSummary(s, s._count.photos)]));
  }
}

/** Yozma vazifa — o'qituvchi sarlavhasi; aks holda katalog nomi (avvalgidek). */
const titleOf = (a: SchoolLearningAssignment, m: Material | undefined) =>
  a.materialKind === WRITTEN_KIND ? (a.title ?? '—') : (m?.title ?? '—');
