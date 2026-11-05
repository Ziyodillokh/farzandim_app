import type { HomeworkSubmission, StudentSubmissionRow, SubmissionRecord } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { type ReviewInput, reviewInputSchema, WRITTEN_MATERIAL_ID } from '@/data/schemas/learning';
import { parseOrThrow } from '@/data/schemas/validate';
import { allowedClassIds, assertCan, assertClassInScope, currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { buildIndexes, compareClasses, studentFullName, studentName } from '../lookups';
import { notebookPhotoUrl } from '../seed/notebook-photo';
import { nowLocalIso } from './comms-shared';

/**
 * Yozma vazifa topshiriqlari. Ko'rish — `learning.view` (sinf rahbari: faqat o'z sinfi o'quvchilari),
 * tekshirish (qabul / izoh bilan qaytarish) — `learning.assign` (topshiriq berish bilan bir xil).
 * Rasm havolalari o'qishda yasaladi (haqiqiy rejimda — ~1 soatlik imzolangan URL).
 */

function toSubmission(record: SubmissionRecord): HomeworkSubmission {
  return {
    id: record.id,
    status: record.status,
    comment: record.comment || null,
    submittedAt: record.submittedAt,
    reviewedAt: record.reviewedAt,
    reviewNote: record.reviewNote,
    photos: record.photoIds.map((id) => ({ id, url: notebookPhotoUrl(id) })),
  };
}

export const learningSubmissionsService = {
  /** Topshiriq sinflari o'quvchilari (doira bo'yicha) va ularning ishlari; topshirmaganda `submission: null`. */
  async submissions(assignmentId: string): Promise<StudentSubmissionRow[]> {
    await latency(60, 160);
    const actor = currentActor();
    assertCan(actor, 'learning.view');
    const t = getTables();
    const assignment = t.assignments.find((a) => a.id === assignmentId);
    if (!assignment || assignment.materialId !== WRITTEN_MATERIAL_ID) throw new ServiceError('NOT_FOUND', assignmentId);
    const allowed = allowedClassIds(actor);
    if (allowed && !assignment.classIds.some((id) => allowed.includes(id))) throw new ServiceError('FORBIDDEN', assignmentId);
    const idx = buildIndexes(t);
    const records = new Map(t.submissions.filter((s) => s.assignmentId === assignmentId).map((s) => [s.studentId, s]));
    return t.students
      .filter((s) => !s.archived && assignment.classIds.includes(s.classId) && (!allowed || allowed.includes(s.classId)))
      .sort((a, b) => {
        const classA = idx.classes.get(a.classId);
        const classB = idx.classes.get(b.classId);
        return (classA && classB ? compareClasses(classA, classB) : 0) || studentName(a).localeCompare(studentName(b), 'uz');
      })
      .map((s) => {
        const record = records.get(s.id);
        return { student: { id: s.id, fullName: studentFullName(s) }, classId: s.classId, submission: record ? toSubmission(record) : null };
      });
  },

  /** Ishni qabul qilish yoki izoh bilan qaytarish (qaytarishda izoh majburiy, ≤ 500). */
  async reviewSubmission(submissionId: string, input: ReviewInput): Promise<HomeworkSubmission> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'learning.assign');
    const data = parseOrThrow(reviewInputSchema, input);
    return transact((t) => {
      const record = t.submissions.find((s) => s.id === submissionId);
      const student = record ? t.students.find((s) => s.id === record.studentId) : undefined;
      if (!record || !student) throw new ServiceError('NOT_FOUND', submissionId);
      assertClassInScope(actor, student.classId);
      const assignment = t.assignments.find((a) => a.id === record.assignmentId);
      const next: SubmissionRecord = { ...record, status: data.status, reviewedAt: nowLocalIso(), reviewNote: data.note?.trim() || null };
      t.submissions = t.submissions.map((s) => (s.id === submissionId ? next : s));
      const name = studentFullName(student);
      const title = assignment?.title ?? '—';
      const accepted = data.status === 'ACCEPTED';
      writeAudit(t, actor, 'LEARNING', 'learning.review', `${name}: «${title}» — ${accepted ? 'qabul qilindi' : 'qaytarildi'}`, submissionId, record, next, {
        student: name,
        title,
        variant: accepted ? 'accepted' : 'returned',
      });
      return toSubmission(next);
    });
  },
};
