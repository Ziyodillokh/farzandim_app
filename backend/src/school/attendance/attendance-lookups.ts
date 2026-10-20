// Davomat o'qishlari uchun yordamchi so'rovlar: bayramlar, ismlar, sinf nomlari,
// jonli oqim elementlari. Har so'rov `schoolId` bilan cheklanadi (tenant).

import { Prisma, SchoolAttendanceEvent } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { studentName, toEventView } from './attendance-view';

/** Unikal cheklov (parallel so'rov bir xil yozuvni yaratdi). */
export const isUniqueViolation = (err: unknown) =>
  err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';

export async function loadHolidays(prisma: PrismaService, schoolId: string): Promise<Set<string>> {
  const rows = await prisma.schoolHoliday.findMany({ where: { schoolId }, select: { date: true } });
  return new Set(rows.map((h) => h.date));
}

export async function studentNames(
  prisma: PrismaService,
  schoolId: string,
  ids: Iterable<string>,
): Promise<Map<string, string>> {
  const unique = [...new Set(ids)];
  if (unique.length === 0) return new Map();
  const rows = await prisma.schoolStudent.findMany({
    where: { schoolId, id: { in: unique } },
    select: { id: true, firstName: true, lastName: true },
  });
  return new Map(rows.map((s) => [s.id, studentName(s)]));
}

export async function classNames(
  prisma: PrismaService,
  schoolId: string,
  ids: Iterable<string | null>,
): Promise<Map<string, string>> {
  const unique = [...new Set([...ids].filter((id): id is string => Boolean(id)))];
  if (unique.length === 0) return new Map();
  const rows = await prisma.schoolClass.findMany({
    where: { schoolId, id: { in: unique } },
    select: { id: true, name: true },
  });
  return new Map(rows.map((c) => [c.id, c.name]));
}

export async function staffNames(
  prisma: PrismaService,
  schoolId: string,
  ids: Iterable<string | null>,
): Promise<Map<string, string>> {
  const unique = [...new Set([...ids].filter((id): id is string => Boolean(id)))];
  if (unique.length === 0) return new Map();
  const rows = await prisma.schoolStaff.findMany({
    where: { schoolId, id: { in: unique } },
    select: { id: true, fullName: true },
  });
  return new Map(rows.map((s) => [s.id, s.fullName]));
}

/** Panel `FeedItem`: hodisa + o'quvchi ismi + sinf nomi. */
export async function toFeedItems(prisma: PrismaService, schoolId: string, events: SchoolAttendanceEvent[]) {
  const [names, classes] = await Promise.all([
    studentNames(prisma, schoolId, events.map((e) => e.studentId)),
    classNames(prisma, schoolId, events.map((e) => e.classId)),
  ]);
  return events.map((e) => ({
    ...toEventView(e),
    studentName: names.get(e.studentId) ?? '—',
    className: (e.classId && classes.get(e.classId)) || '',
  }));
}

export type FeedItemView = Awaited<ReturnType<typeof toFeedItems>>[number];
