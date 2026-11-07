// Parvoz Growth bola ilovasi: tokendagi bola -> maktab o'quvchisi. Bola ota-ona
// tomonidan maktabga bog'langan (`SchoolStudent.childId`), arxivlanmagan, sinfi bor
// va maktab faol bo'lishi shart. Aks holda 404 `NOT_ENROLLED` — boshqa bola
// maktab yo'llari (so'rovnoma, psixologga murojaat) bilan bir xil javob.
// Bola "maktab / sinf noto'g'ri" so'rovini ochgan bo'lsa (A08, OPEN) maktab ma'lumoti
// YOPILADI: `findEnrolledStudent` — `null`, `requireEnrolledStudent` — 404 `UNDER_REVIEW`
// (eski ilovalar uni "ulanmagan" deb qabul qiladi).

import { NotFoundException } from '@nestjs/common';
import { Prisma, SchoolShift } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { type ChildLang, childLang } from '../assessments/child-view';

export interface EnrolledStudent {
  childId: string;
  studentId: string;
  schoolId: string;
  classId: string;
  className: string;
  /** Sinf darajasi (1..11). */
  grade: number;
  /** Bola ilovasi tili (`User.language`; noma'lum — `uz`). */
  lang: ChildLang;
  /** Maktabga qabul sanasi (YYYY-MM-DD). */
  enrolledAt: string;
  shift: SchoolShift;
}

export const notEnrolled = () =>
  new NotFoundException({ code: 'NOT_ENROLLED', message: 'Child is not linked to a school' });

/** Bog'lanish tuzatish ko'rib chiqilguncha ochiq: maktab ma'lumoti yopiq. */
export const underReview = () =>
  new NotFoundException({ code: 'UNDER_REVIEW', message: 'School link is under review' });

/**
 * `SchoolStudent` so'rovida bolaning ochiq tuzatish so'rovi bormi (bo'sh bo'lmagan massiv — ha).
 * Maktab ma'lumotini bolaga beradigan har bir alohida qidiruv shuni qo'shishi shart.
 */
export const openCorrectionArgs = (childId: string) =>
  ({ where: { childId, status: 'OPEN' }, select: { id: true }, take: 1 }) satisfies Prisma.SchoolStudent$linkCorrectionsArgs;

type Enrollment = { student: EnrolledStudent | null; underReview: boolean };

async function resolveEnrollment(prisma: PrismaService, childUserId: string): Promise<Enrollment> {
  const none: Enrollment = { student: null, underReview: false };
  const child = await prisma.child.findUnique({
    where: { childUserId },
    select: { id: true, childUser: { select: { language: true } } },
  });
  if (!child) return none;
  const student = await prisma.schoolStudent.findUnique({
    where: { childId: child.id },
    select: {
      id: true,
      schoolId: true,
      archived: true,
      enrolledAt: true,
      class: { select: { id: true, name: true, grade: true, shift: true } },
      school: { select: { status: true } },
      linkCorrections: openCorrectionArgs(child.id),
    },
  });
  if (!student || student.archived || !student.class || student.school.status !== 'ACTIVE') return none;
  if (student.linkCorrections.length > 0) return { student: null, underReview: true };
  return {
    underReview: false,
    student: {
      childId: child.id,
      studentId: student.id,
      schoolId: student.schoolId,
      classId: student.class.id,
      className: student.class.name,
      grade: student.class.grade,
      lang: childLang(child.childUser?.language),
      enrolledAt: student.enrolledAt,
      shift: student.class.shift,
    },
  };
}

/** Bog'langan o'quvchi yoki `null` (xato tashlamaydi; ochiq tuzatish so'rovi bo'lsa ham `null`). */
export async function findEnrolledStudent(prisma: PrismaService, childUserId: string): Promise<EnrolledStudent | null> {
  return (await resolveEnrollment(prisma, childUserId)).student;
}

/** Bog'langan o'quvchi; aks holda 404 `NOT_ENROLLED` (ochiq tuzatish so'rovi bo'lsa — 404 `UNDER_REVIEW`). */
export async function requireEnrolledStudent(prisma: PrismaService, childUserId: string): Promise<EnrolledStudent> {
  const { student, underReview: closed } = await resolveEnrollment(prisma, childUserId);
  if (student) return student;
  throw closed ? underReview() : notEnrolled();
}
