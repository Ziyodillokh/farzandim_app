// Kirish nuqtasi (kiosk): aylanuvchi QR tokeni, o'quvchi kodi bo'yicha kirish
// (telefonsiz o'quvchi), qidiruv va kiosk hisoblagichlari (panel `attendanceService`).

import { Injectable } from '@nestjs/common';
import { SchoolStudent } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { compareUz, matchesSearch } from '../common/list-query';
import { notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { AttendanceArrivalService } from './attendance-arrival.service';
import { KioskTokenService } from './attendance-kiosk-token';
import { classNames, loadHolidays, toFeedItems } from './attendance-lookups';
import { AttendanceClock, isSchoolDay } from './attendance-time';
import { studentName } from './attendance-view';
import { kioskCheckInSchema, kioskSearchQuerySchema } from './attendance.schemas';

const SEARCH_LIMIT = 8;
const RECENT_LIMIT = 6;
const MIN_QUERY = 2;

/** Panel `Student` kontrakti. */
function toStudentView(s: SchoolStudent & { guardians: Array<{ guardianId: string }> }) {
  return {
    id: s.id,
    lastName: s.lastName,
    firstName: s.firstName,
    middleName: s.middleName,
    gender: s.gender,
    birthDate: s.birthDate,
    classId: s.classId ?? '',
    device: s.device,
    guardianIds: s.guardians.map((g) => g.guardianId),
    studentCode: s.studentCode,
    enrolledAt: s.enrolledAt,
    archived: s.archived,
  };
}

@Injectable()
export class AttendanceKioskService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
    private readonly clock: AttendanceClock,
    private readonly tokens: KioskTokenService,
    private readonly arrival: AttendanceArrivalService,
  ) {}

  /** Joriy QR tokeni (30 soniyalik oyna). */
  async token(actor: SchoolActor) {
    assertCan(actor, 'attendance.kiosk');
    const school = await this.prisma.school.findUniqueOrThrow({
      where: { id: actor.schoolId },
      select: { kioskSecret: true },
    });
    return this.tokens.issue(actor.schoolId, school.kioskSecret, this.clock.now());
  }

  /** O'quvchi kodi (P-1234) yoki ID bo'yicha kirishni qayd etish. */
  async checkIn(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'attendance.kiosk');
    const code = parseOrThrow(kioskCheckInSchema, input).code;
    const student = await this.prisma.schoolStudent.findFirst({
      where: {
        schoolId: actor.schoolId,
        archived: false,
        OR: [{ studentCode: { equals: code, mode: 'insensitive' } }, { id: code }],
      },
      include: { class: { include: { shift: true } }, guardians: { select: { guardianId: true } } },
    });
    if (!student) throw notFound(code);
    const cls = student.class;
    if (!cls) throw notFound(student.classId ?? 'class');
    const school = await this.prisma.school.findUniqueOrThrow({
      where: { id: actor.schoolId },
      select: { lateAfterMinutes: true },
    });
    const name = studentName(student);
    const result = await this.arrival.arrive(
      {
        schoolId: actor.schoolId,
        studentId: student.id,
        classId: cls.id,
        shiftStart: cls.shift.start,
        lateAfterMinutes: school.lateAfterMinutes,
        source: 'KIOSK',
        byStaffId: actor.staffId,
        now: this.clock.now(),
      },
      (tx, record) =>
        this.audit.write(
          actor,
          {
            module: 'ATTENDANCE',
            action: 'attendance.kiosk',
            summary: `${name} (${cls.name}) — ${record.status}`,
            entityId: record.id,
            params: { name, className: cls.name, status: record.status },
          },
          tx,
        ),
    );
    return {
      student: toStudentView(student),
      className: cls.name,
      status: result.record.status,
      alreadyIn: result.alreadyIn,
    };
  }

  /** Kiosk qidiruvi (ism yoki kod bo'yicha, telefonsiz o'quvchi uchun). */
  async kioskSearch(actor: SchoolActor, query: unknown) {
    assertCan(actor, 'attendance.kiosk');
    const term = parseOrThrow(kioskSearchQuerySchema, query ?? {}).q.trim();
    if (term.length < MIN_QUERY) return [];
    const students = await this.prisma.schoolStudent.findMany({
      where: { schoolId: actor.schoolId, archived: false },
      select: { id: true, firstName: true, lastName: true, studentCode: true, classId: true },
    });
    const matched = students
      .map((s) => ({ ...s, name: studentName(s) }))
      .filter((s) => matchesSearch(s.name, term) || matchesSearch(s.studentCode, term))
      .sort((a, b) => compareUz(a.name, b.name))
      .slice(0, SEARCH_LIMIT);
    const ids = matched.map((s) => s.id);
    const [classes, inToday] = await Promise.all([
      classNames(this.prisma, actor.schoolId, matched.map((s) => s.classId)),
      this.prisma.schoolAttendance.findMany({
        where: { schoolId: actor.schoolId, date: tashkentDay(this.clock.now()), studentId: { in: ids }, inAt: { not: null } },
        select: { studentId: true },
      }),
    ]);
    const arrived = new Set(inToday.map((r) => r.studentId));
    return matched.map((s) => ({
      id: s.id,
      name: s.name,
      className: (s.classId && classes.get(s.classId)) || '',
      studentCode: s.studentCode,
      inToday: arrived.has(s.id),
    }));
  }

  /** Kiosk ekrani: bugun kelganlar / kechikkanlar va oxirgi kirishlar. */
  async kioskStats(actor: SchoolActor) {
    assertCan(actor, 'attendance.kiosk');
    const today = tashkentDay(this.clock.now());
    const [classes, holidays] = await Promise.all([
      this.prisma.schoolClass.findMany({
        where: { schoolId: actor.schoolId },
        select: { id: true, shift: { select: { weekdays: true } } },
      }),
      loadHolidays(this.prisma, actor.schoolId),
    ]);
    const activeClassIds = classes.filter((c) => isSchoolDay(today, c.shift, holidays)).map((c) => c.id);
    const arrivedWhere = { schoolId: actor.schoolId, date: today, inAt: { not: null } };
    const [expected, arrived, late, recentEvents] = await Promise.all([
      this.prisma.schoolStudent.count({
        where: { schoolId: actor.schoolId, archived: false, classId: { in: activeClassIds } },
      }),
      this.prisma.schoolAttendance.count({ where: arrivedWhere }),
      this.prisma.schoolAttendance.count({ where: { ...arrivedWhere, status: 'LATE' } }),
      this.prisma.schoolAttendanceEvent.findMany({
        where: { schoolId: actor.schoolId, date: today, kind: 'IN' },
        orderBy: { at: 'desc' },
        take: RECENT_LIMIT,
      }),
    ]);
    const recent = await toFeedItems(this.prisma, actor.schoolId, recentEvents);
    return { date: today, expected, arrived, late, recent };
  }
}
