// Yozma vazifa — xodim tomoni: topshiriq bo'yicha o'quvchilar va ularning topshiriqlari
// (rasm havolalari bilan), qabul qilish / qaytarish. Doira: ADMIN / DIRECTOR — butun maktab,
// sinf rahbari — faqat o'z sinflari. Baholash `learning.assign` ruxsatini talab qiladi.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { allowedClassIds, assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { compareClasses } from '../common/list-query';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, forbidden, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { WRITTEN_KIND } from '../learning/school-learning.schemas';
import { HomeworkPhotoUrlService } from './homework-photo-url.service';
import { toStaffSubmissionView } from './homework-view';
import { reviewInputSchema } from './homework.schemas';

@Injectable()
export class HomeworkStaffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
    private readonly urls: HomeworkPhotoUrlService,
  ) {}

  /** Topshiriq sinflaridagi (arxivsiz) o'quvchilar va ularning topshiriqlari (yo'q — `null`). */
  async submissions(actor: SchoolActor, assignmentId: string) {
    assertCan(actor, 'learning.view');
    const assignment = await this.prisma.schoolLearningAssignment.findFirst({
      where: { id: assignmentId, schoolId: actor.schoolId, materialKind: WRITTEN_KIND },
    });
    if (!assignment) throw notFound(assignmentId);
    const allowed = allowedClassIds(actor);
    const classIds = allowed ? assignment.classIds.filter((id) => allowed.includes(id)) : assignment.classIds;
    if (classIds.length === 0) throw forbidden(assignmentId);
    const [classes, students, submissions] = await Promise.all([
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId, id: { in: classIds } }, select: { id: true, name: true, grade: true, letter: true } }),
      this.prisma.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, archived: false, classId: { in: classIds } },
        select: { id: true, classId: true, lastName: true, firstName: true },
      }),
      this.prisma.schoolHomeworkSubmission.findMany({ where: { assignmentId, student: { classId: { in: classIds } } }, include: { photos: true } }),
    ]);
    const classOf = new Map(classes.map((c) => [c.id, c]));
    const submissionOf = new Map(submissions.map((s) => [s.studentId, s]));
    const rank = new Map([...classes].sort(compareClasses).map((c, i) => [c.id, i]));
    const rows = [...students]
      .sort((a, b) => (rank.get(a.classId ?? '') ?? 0) - (rank.get(b.classId ?? '') ?? 0) || `${a.lastName} ${a.firstName}`.localeCompare(`${b.lastName} ${b.firstName}`))
      .map((s) => {
        const submission = submissionOf.get(s.id);
        return {
          studentId: s.id,
          name: `${s.lastName} ${s.firstName}`,
          classId: s.classId,
          className: (s.classId && classOf.get(s.classId)?.name) || '',
          submission: submission ? toStaffSubmissionView(submission, (id) => this.urls.url(id)) : null,
        };
      });
    return {
      assignment: {
        id: assignment.id,
        title: assignment.title,
        dueDate: assignment.dueDate,
        estimatedMinutes: assignment.estimatedMinutes,
        note: assignment.note,
        classIds,
      },
      counts: {
        total: rows.length,
        submitted: rows.filter((r) => r.submission?.status === 'SUBMITTED').length,
        accepted: rows.filter((r) => r.submission?.status === 'ACCEPTED').length,
        returned: rows.filter((r) => r.submission?.status === 'RETURNED').length,
        missing: rows.filter((r) => !r.submission).length,
      },
      students: rows,
    };
  }

  async review(actor: SchoolActor, submissionId: string, body: unknown) {
    assertCan(actor, 'learning.assign');
    const input = parseOrThrow(reviewInputSchema, body ?? {});
    const found = await this.prisma.schoolHomeworkSubmission.findFirst({
      where: { id: submissionId, assignment: { schoolId: actor.schoolId, materialKind: WRITTEN_KIND } },
      include: { photos: true, assignment: { select: { title: true } }, student: { select: { classId: true, lastName: true, firstName: true } } },
    });
    if (!found) throw notFound(submissionId);
    assertClassInScope(actor, found.student.classId);
    const name = `${found.student.lastName} ${found.student.firstName}`;
    const reviewedAt = new Date();
    const updated = await this.prisma.$transaction(async (tx) => {
      // Bola shu orada qayta yuborgan bo'lsa (submittedAt o'zgargan) — eski rasmlar baholanmasin.
      const res = await tx.schoolHomeworkSubmission.updateMany({
        where: { id: found.id, submittedAt: found.submittedAt },
        data: { status: input.status, reviewedAt, reviewedByStaffId: actor.staffId, reviewNote: input.note },
      });
      if (res.count !== 1) throw conflict('resubmitted');
      await this.audit.write(
        actor,
        {
          module: 'LEARNING',
          action: 'homework.review',
          summary: `${name}: "${found.assignment.title ?? ''}" — ${input.status}`,
          entityId: found.id,
          params: { name, title: found.assignment.title ?? '', status: input.status },
        },
        tx,
      );
      return tx.schoolHomeworkSubmission.findUniqueOrThrow({ where: { id: found.id }, include: { photos: true } });
    });
    return toStaffSubmissionView(updated, (id) => this.urls.url(id));
  }
}
