// Parvoz Growth bola ilovasi: o'z sinfiga berilgan maktab topshiriqlari.
// Test topshirig'i shu fan bo'yicha topshiriq berilgandan keyin yakunlangan
// kunlik test bilan "bajarildi" hisoblanadi. Yozma vazifa (WRITTEN) — rasm
// topshiriladi, o'qituvchi QABUL qilgandagina "bajarildi". Maktab materiali
// (LESSON) — matn va havola; bola "O'qidim" bosganda "bajarildi".

import { Injectable, NotFoundException } from "@nestjs/common";
import { SchoolLearningAssignment } from "@prisma/client";
import { PrismaService } from "../../common/database/prisma.service";
import { tashkentDay } from "../../common/time/tashkent";
import { openCorrectionArgs } from "../common/child-student";
import { toSubmissionSummary } from "../homework/homework-view";
import { childAssignmentWhere } from "./assignment-visibility";
import {
  loadCatalog,
  Material,
  testSubjectOf,
} from "./school-learning-catalog";
import { WRITTEN_KIND } from "./school-learning.schemas";
import { LESSON_KIND, parseSchoolMaterialId } from "./school-materials";

type SubmissionSummary = ReturnType<typeof toSubmissionSummary>;

@Injectable()
export class SchoolLearningChildService {
  constructor(private readonly prisma: PrismaService) {}

  async assignments(childUserId: string) {
    const enrolled = await this.enrolled(childUserId);
    if (!enrolled) return [];
    const { child, student } = enrolled;
    const today = tashkentDay();
    const [rows, catalog] = await Promise.all([
      this.prisma.schoolLearningAssignment.findMany({
        where: childAssignmentWhere(
          { schoolId: student.schoolId, classId: student.classId },
          today,
        ),
        orderBy: { dueDate: "asc" },
      }),
      loadCatalog(this.prisma),
    ]);
    const material = new Map(catalog.map((m) => [m.id, m]));
    const [teachers, submissions, lessons, reads] = await Promise.all([
      this.teacherNames(student.schoolId, rows),
      this.submissionSummaries(student.id, rows),
      this.lessonMaterials(student.schoolId, rows),
      this.prisma.schoolMaterialRead.findMany({
        where: {
          studentId: student.id,
          assignmentId: {
            in: rows
              .filter((r) => r.materialKind === LESSON_KIND)
              .map((r) => r.id),
          },
        },
        select: { assignmentId: true, readAt: true },
      }),
    ]);
    const readAt = new Map(
      reads.map((r) => [r.assignmentId, r.readAt.toISOString()]),
    );
    return Promise.all(
      rows.map(async (a) => {
        const written = a.materialKind === WRITTEN_KIND;
        const lesson =
          a.materialKind === LESSON_KIND
            ? (lessons.get(a.materialId) ?? null)
            : null;
        const m = material.get(a.materialId);
        const subject = testSubjectOf(a.materialId);
        const submission = written ? (submissions.get(a.id) ?? null) : null;
        const done = written
          ? submission?.status === "ACCEPTED"
          : a.materialKind === LESSON_KIND
            ? readAt.has(a.id)
            : subject
              ? (await this.prisma.learningAttempt.count({
                  where: {
                    childId: child.id,
                    subject,
                    status: "COMPLETED",
                    completedAt: { gte: a.createdAt },
                  },
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
          /** Maktab materiali (LESSON): matn, havola va "O'qidim" vaqti; boshqalarda `null`. */
          lesson: lesson
            ? {
                body: lesson.body,
                linkUrl: lesson.linkUrl,
                readAt: readAt.get(a.id) ?? null,
              }
            : null,
        };
      }),
    );
  }

  /** "O'qidim": faqat bolaga ko'rinadigan maktab materiali topshirig'i; boshqasi — 404 (mavjudligi oshkor bo'lmaydi). */
  async markRead(childUserId: string, assignmentId: string) {
    const enrolled = await this.enrolled(childUserId);
    if (!enrolled) throw assignmentNotFound();
    const { student } = enrolled;
    const assignment = await this.prisma.schoolLearningAssignment.findFirst({
      where: {
        id: assignmentId,
        materialKind: LESSON_KIND,
        ...childAssignmentWhere(
          { schoolId: student.schoolId, classId: student.classId },
          tashkentDay(),
        ),
      },
      select: { id: true },
    });
    if (!assignment) throw assignmentNotFound();
    const read = await this.prisma.schoolMaterialRead.upsert({
      where: {
        assignmentId_studentId: {
          assignmentId: assignment.id,
          studentId: student.id,
        },
      },
      create: { assignmentId: assignment.id, studentId: student.id },
      update: {},
    });
    return { id: assignment.id, done: true, readAt: read.readAt.toISOString() };
  }

  /** Bolaning faol, tasdiqlangan, sinfli o'quvchi yozuvi (ochiq tuzatish so'rovi bo'lsa — yo'q). */
  private async enrolled(childUserId: string) {
    const child = await this.prisma.child.findUnique({
      where: { childUserId },
      select: { id: true },
    });
    const student = child
      ? await this.prisma.schoolStudent.findUnique({
          where: { childId: child.id },
          select: {
            id: true,
            schoolId: true,
            classId: true,
            archived: true,
            school: { select: { status: true } },
            linkCorrections: openCorrectionArgs(child.id),
          },
        })
      : null;
    // Ochiq "maktab / sinf noto'g'ri" so'rovi (A08): bolaning maktab ma'lumoti yopiq.
    if (
      !child ||
      !student ||
      student.archived ||
      !student.classId ||
      student.school.status !== "ACTIVE" ||
      student.linkCorrections.length > 0
    )
      return null;
    return { child, student: { ...student, classId: student.classId } };
  }

  /** Topshiriqlardagi maktab materiallari (arxivdagisi ham — yuborilgan topshiriq ochilaversin). */
  private async lessonMaterials(
    schoolId: string,
    rows: readonly SchoolLearningAssignment[],
  ) {
    const ids = rows
      .flatMap((r) =>
        r.materialKind === LESSON_KIND
          ? [parseSchoolMaterialId(r.materialId)]
          : [],
      )
      .filter((id): id is string => !!id);
    if (ids.length === 0)
      return new Map<string, { body: string; linkUrl: string | null }>();
    const found = await this.prisma.schoolLearningMaterial.findMany({
      where: { schoolId, id: { in: [...new Set(ids)] } },
      select: { id: true, body: true, linkUrl: true },
    });
    return new Map(
      found.map((m) => [
        `school:${m.id}`,
        { body: m.body, linkUrl: m.linkUrl },
      ]),
    );
  }

  private async teacherNames(
    schoolId: string,
    rows: readonly SchoolLearningAssignment[],
  ) {
    const ids = [...new Set(rows.map((r) => r.byStaffId))];
    if (ids.length === 0) return new Map<string, string>();
    const staff = await this.prisma.schoolStaff.findMany({
      where: { schoolId, id: { in: ids } },
      select: { id: true, fullName: true },
    });
    return new Map(staff.map((s) => [s.id, s.fullName]));
  }

  /** Yozma vazifalar bo'yicha o'quvchining topshiriqlari (rasm soni bilan). */
  private async submissionSummaries(
    studentId: string,
    rows: readonly SchoolLearningAssignment[],
  ) {
    const writtenIds = rows
      .filter((r) => r.materialKind === WRITTEN_KIND)
      .map((r) => r.id);
    if (writtenIds.length === 0) return new Map<string, SubmissionSummary>();
    const found = await this.prisma.schoolHomeworkSubmission.findMany({
      where: { studentId, assignmentId: { in: writtenIds } },
      include: { _count: { select: { photos: true } } },
    });
    return new Map(
      found.map((s) => [
        s.assignmentId,
        toSubmissionSummary(s, s._count.photos),
      ]),
    );
  }
}

/** Yozma vazifa va maktab materiali — topshiriqdagi sarlavha; aks holda katalog nomi (avvalgidek). */
const titleOf = (a: SchoolLearningAssignment, m: Material | undefined) =>
  a.materialKind === WRITTEN_KIND || a.materialKind === LESSON_KIND
    ? (a.title ?? "—")
    : (m?.title ?? "—");

const assignmentNotFound = () =>
  new NotFoundException({ code: "NOT_FOUND", message: "Assignment not found" });
