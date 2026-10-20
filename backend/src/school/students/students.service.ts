// O'quvchilar (panel `studentsService`): filtr uchun sinflar, ro'yxat (doira,
// filtr, qidiruv, saralash) va karta tafsiloti. Yozish — `students-write`,
// 360° tarix va eslatmalar — `student-360`.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import {
  actorCan,
  allowedClassIds,
  assertCan,
  assertClassInScope,
  SchoolActor,
} from '../auth/school-actor';
import { deviceStateOf } from '../common/device-state';
import { runListQuery } from '../common/list-query';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import {
  redact,
  studentInclude,
  StudentRow,
  toAttendanceRecordView,
  toExceptionView,
  toGuardianView,
  toStudentRow,
} from './student-view';
import { StudentFilter, studentFilterSchema } from './students.schemas';

@Injectable()
export class StudentsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Filtr va formalar uchun doiradagi sinflar (faqat id va nom). */
  async classOptions(actor: SchoolActor): Promise<Array<{ id: string; name: string }>> {
    assertCan(actor, 'students.view');
    const allowed = allowedClassIds(actor);
    return this.prisma.schoolClass.findMany({
      where: { schoolId: actor.schoolId, ...(allowed && { id: { in: allowed } }) },
      orderBy: [{ grade: 'asc' }, { letter: 'asc' }],
      select: { id: true, name: true },
    });
  }

  async list(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'students.view');
    const filter = parseOrThrow(studentFilterSchema, query);
    if (filter.classId) assertClassInScope(actor, filter.classId);
    const rows = await this.rows(actor, filter);
    return runListQuery(rows, filter, {
      searchText: (r) => `${r.fullName} ${r.studentCode} ${r.className} ${r.guardianNames.join(' ')}`,
      sorters: {
        name: (r) => `${r.lastName} ${r.firstName}`,
        class: (r) => `${String(r.grade).padStart(2, '0')} ${r.className}`,
        birthDate: (r) => r.birthDate,
        link: (r) => r.linkStatus,
      },
      defaultSort: 'name',
    });
  }

  async get(actor: SchoolActor, id: string) {
    assertCan(actor, 'students.view');
    const student = await this.prisma.schoolStudent.findFirst({
      where: { id, schoolId: actor.schoolId },
      include: {
        ...studentInclude,
        class: { include: { shift: { select: { name: true } }, homeroom: { select: { fullName: true } } } },
      },
    });
    if (!student) throw notFound(id);
    assertClassInScope(actor, student.classId);
    const now = new Date();
    const today = await this.prisma.schoolAttendance.findUnique({
      where: { studentId_date: { studentId: id, date: tashkentDay(now) } },
      include: { corrections: { orderBy: { at: 'asc' } } },
    });
    const row = toStudentRow(student, today?.status ?? null, now);
    const extra = {
      homeroomName: student.class?.homeroom?.fullName ?? null,
      shiftName: student.class?.shift.name ?? '',
    };
    // Psixolog uchun minimal ma'lumot (faqat ism va sinf).
    if (!actorCan(actor, 'guardians.link')) {
      return { ...redact(row), ...extra, guardians: [], today: null, exceptions: [], deviceState: null };
    }
    const [guardians, exceptions] = await Promise.all([
      this.prisma.schoolGuardian.findMany({
        where: { schoolId: actor.schoolId, students: { some: { studentId: id } } },
        orderBy: { createdAt: 'asc' },
      }),
      this.prisma.schoolModeException.findMany({
        where: { schoolId: actor.schoolId, studentId: id },
        orderBy: { from: 'desc' },
      }),
    ]);
    return {
      ...row,
      ...extra,
      guardians: guardians.map(toGuardianView),
      today: today ? toAttendanceRecordView(today) : null,
      exceptions: exceptions.map(toExceptionView),
      deviceState: deviceStateOf(student, student.child, now),
    };
  }

  /** Doiradagi o'quvchilar qatorlari (ota-ona huquqi yo'q rol uchun — qisqartirilgan). */
  private async rows(actor: SchoolActor, filter: StudentFilter): Promise<StudentRow[]> {
    const allowed = allowedClassIds(actor);
    const where: Prisma.SchoolStudentWhereInput = {
      schoolId: actor.schoolId,
      ...(allowed && { classId: { in: allowed } }),
      ...(filter.classId && { classId: filter.classId }),
      ...(!filter.includeArchived && { archived: false }),
      ...(filter.device && { device: filter.device }),
    };
    const now = new Date();
    const [students, todays] = await Promise.all([
      this.prisma.schoolStudent.findMany({ where, include: studentInclude }),
      this.prisma.schoolAttendance.findMany({
        where: { schoolId: actor.schoolId, date: tashkentDay(now), student: where },
        select: { studentId: true, status: true },
      }),
    ]);
    const todayStatus = new Map(todays.map((r) => [r.studentId, r.status]));
    const minimal = !actorCan(actor, 'guardians.link');
    return students
      .map((s) => toStudentRow(s, todayStatus.get(s.id) ?? null, now))
      .map((r) => (minimal ? redact(r) : r))
      .filter((r) => !filter.linkStatus || r.linkStatus === filter.linkStatus);
  }
}
