// Parvoz Growth bola ilovasi: tokendagi bola -> maktab o'quvchisi. Bola ota-ona
// tomonidan maktabga bog'langan (`SchoolStudent.childId`), arxivlanmagan, sinfi bor
// va maktab faol bo'lishi shart. Aks holda 404 `NOT_ENROLLED` — boshqa bola
// maktab yo'llari (so'rovnoma, psixologga murojaat) bilan bir xil javob.

import { NotFoundException } from '@nestjs/common';
import { SchoolShift } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

export interface EnrolledStudent {
  childId: string;
  studentId: string;
  schoolId: string;
  classId: string;
  className: string;
  /** Sinf darajasi (1..11). */
  grade: number;
  /** Bola ilovasi tili (`User.language`; noma'lum — `uz`). */
  lang: 'uz' | 'ru';
  /** Maktabga qabul sanasi (YYYY-MM-DD). */
  enrolledAt: string;
  shift: SchoolShift;
}

export const notEnrolled = () =>
  new NotFoundException({ code: 'NOT_ENROLLED', message: 'Child is not linked to a school' });

/** Bog'langan o'quvchi yoki `null` (xato tashlamaydi). */
export async function findEnrolledStudent(prisma: PrismaService, childUserId: string): Promise<EnrolledStudent | null> {
  const child = await prisma.child.findUnique({
    where: { childUserId },
    select: { id: true, childUser: { select: { language: true } } },
  });
  if (!child) return null;
  const student = await prisma.schoolStudent.findUnique({
    where: { childId: child.id },
    select: {
      id: true,
      schoolId: true,
      archived: true,
      enrolledAt: true,
      class: { select: { id: true, name: true, grade: true, shift: true } },
      school: { select: { status: true } },
    },
  });
  if (!student || student.archived || !student.class || student.school.status !== 'ACTIVE') return null;
  return {
    childId: child.id,
    studentId: student.id,
    schoolId: student.schoolId,
    classId: student.class.id,
    className: student.class.name,
    grade: student.class.grade,
    lang: child.childUser?.language === 'ru' ? 'ru' : 'uz',
    enrolledAt: student.enrolledAt,
    shift: student.class.shift,
  };
}

/** Bog'langan o'quvchi; aks holda 404 `NOT_ENROLLED`. */
export async function requireEnrolledStudent(prisma: PrismaService, childUserId: string): Promise<EnrolledStudent> {
  const student = await findEnrolledStudent(prisma, childUserId);
  if (!student) throw notEnrolled();
  return student;
}
