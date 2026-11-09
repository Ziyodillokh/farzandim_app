// "Farzandim maktabda": o'quvchining joriy chorak (yoki o'quv yili) bo'yicha
// davomati, kelish vaqti, haftalik dinamika, sinf o'rtachasi (K=5) va maktab
// yozma topshiriqlari. Ota-ona faqat o'z bog'langan o'quvchisini ko'radi (404).

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, tashkentDay } from '../../common/time/tashkent';
import { loadHolidays } from '../attendance/attendance-lookups';
import { dateRange, isSchoolDay } from '../attendance/attendance-time';
import { attendedRate } from '../attendance/attendance-view';
import { notFound } from '../common/school-errors';
import { WRITTEN_KIND } from '../learning/school-learning.schemas';
import {
  attendanceCounts,
  averageArrival,
  classAverage,
  CLASS_MIN_STUDENTS,
  onTimeStreak,
  OverviewDay,
  pickPeriod,
  TREND_WEEKS,
  weeklyRates,
} from './overview-math';
import { studentLabel } from './parent-thread-views';

/** Ko'rsatiladigan yaqin / muddati o'tgan topshiriqlar soni. */
const TASKS_PREVIEW = 5;

@Injectable()
export class ParentOverviewService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(userId: string, studentId: string, now = new Date()) {
    const today = tashkentDay(now);
    const link = await this.prisma.schoolStudentGuardian.findFirst({
      where: { studentId, guardian: { userId, linkStatus: 'LINKED', school: { status: 'ACTIVE' } }, student: { archived: false } },
      include: {
        student: {
          include: {
            class: { include: { shift: true } },
            school: { select: { name: true, shortName: true, quarters: true } },
          },
        },
      },
      orderBy: { guardian: { createdAt: 'asc' } },
    });
    if (!link) throw notFound(studentId);
    const { student } = link;
    const period = pickPeriod(student.school.quarters, today);
    const trendFrom = addDays(today, -7 * TREND_WEEKS);
    const from = period.from < trendFrom ? period.from : trendFrom;

    const [records, holidays] = await Promise.all([
      this.prisma.schoolAttendance.findMany({
        where: { studentId: student.id, date: { gte: from, lte: today } },
        select: { date: true, status: true, inAt: true },
      }),
      loadHolidays(this.prisma, student.schoolId),
    ]);
    const recordOf = new Map(records.map((r) => [r.date, r]));
    const days: OverviewDay[] = dateRange(from, today).map((date) => {
      const r = recordOf.get(date);
      return { date, schoolDay: isSchoolDay(date, student.class?.shift, holidays), status: r?.status ?? null, inAt: r?.inAt ?? null };
    });
    const inPeriod = days.filter((d) => d.date >= period.from);
    const counts = attendanceCounts(inPeriod);

    return {
      student: {
        id: student.id,
        name: studentLabel(student),
        className: student.class?.name ?? '',
        schoolName: student.school.shortName || student.school.name,
      },
      period,
      attendance: {
        ...counts,
        rate: attendedRate(counts),
        averageArrival: averageArrival(inPeriod),
        onTimeStreak: onTimeStreak(days),
        classRate: await this.classRate(student.classId, period.from, today),
        weeks: weeklyRates(days, today),
      },
      tasks: await this.tasks(student.schoolId, student.classId, student.id, period.from, today),
    };
  }

  /** Sinfning shu davrdagi o'rtacha kelish foizi (kamida K o'quvchi). */
  private async classRate(classId: string | null, from: string, today: string): Promise<number | null> {
    if (!classId) return null;
    const students = await this.prisma.schoolStudent.count({ where: { classId, archived: false } });
    if (students < CLASS_MIN_STUDENTS) return null;
    const grouped = await this.prisma.schoolAttendance.groupBy({
      by: ['status'],
      where: { classId, date: { gte: from, lte: today }, student: { archived: false } },
      _count: { _all: true },
    });
    const count = (s: string) => grouped.find((g) => g.status === s)?._count._all ?? 0;
    const attended = count('PRESENT') + count('LATE') + count('LEFT_EARLY');
    const marked = grouped.reduce((sum, g) => sum + g._count._all, 0);
    return classAverage(students, attended, marked);
  }

  /** Sinfga berilgan yozma vazifalar: holatlar soni, sinfdagi topshirish ulushi va yaqinlari. */
  private async tasks(schoolId: string, classId: string | null, studentId: string, from: string, today: string) {
    const empty = { total: 0, submitted: 0, accepted: 0, returned: 0, pending: 0, overdue: 0, classSubmitRate: null, items: [] };
    if (!classId) return empty;
    const assignments = await this.prisma.schoolLearningAssignment.findMany({
      where: { schoolId, materialKind: WRITTEN_KIND, classIds: { has: classId }, createdAt: { gte: new Date(`${from}T00:00:00+05:00`) } },
      orderBy: { dueDate: 'asc' },
      select: { id: true, title: true, dueDate: true, byStaffId: true },
    });
    if (assignments.length === 0) return empty;
    const ids = assignments.map((a) => a.id);
    const [mine, classSubmissions, classSize, teachers] = await Promise.all([
      this.prisma.schoolHomeworkSubmission.findMany({ where: { studentId, assignmentId: { in: ids } }, select: { assignmentId: true, status: true } }),
      this.prisma.schoolHomeworkSubmission.count({ where: { assignmentId: { in: ids }, student: { classId, archived: false } } }),
      this.prisma.schoolStudent.count({ where: { classId, archived: false } }),
      this.prisma.schoolStaff.findMany({
        where: { schoolId, id: { in: [...new Set(assignments.map((a) => a.byStaffId))] } },
        select: { id: true, fullName: true, position: true },
      }),
    ]);
    const statusOf = new Map(mine.map((s) => [s.assignmentId, s.status]));
    const teacherOf = new Map(teachers.map((t) => [t.id, t]));
    const state = (a: { id: string; dueDate: string }) => {
      const s = statusOf.get(a.id);
      if (s === 'ACCEPTED') return 'ACCEPTED' as const;
      if (s === 'RETURNED') return 'RETURNED' as const;
      if (s === 'SUBMITTED') return 'SUBMITTED' as const;
      return a.dueDate < today ? ('OVERDUE' as const) : ('TODO' as const);
    };
    const states = assignments.map((a) => ({ a, state: state(a) }));
    const n = (k: string) => states.filter((x) => x.state === k).length;
    const items = states
      .filter((x) => x.state === 'TODO' || x.state === 'OVERDUE' || x.state === 'RETURNED')
      .sort((x, y) => x.a.dueDate.localeCompare(y.a.dueDate))
      .slice(0, TASKS_PREVIEW)
      .map(({ a, state: s }) => {
        const teacher = teacherOf.get(a.byStaffId);
        return { id: a.id, title: a.title ?? '—', dueDate: a.dueDate, state: s, teacher: teacher ? teacher.position || teacher.fullName : null };
      });
    return {
      total: assignments.length,
      submitted: n('SUBMITTED') + n('ACCEPTED') + n('RETURNED'),
      accepted: n('ACCEPTED'),
      returned: n('RETURNED'),
      pending: n('SUBMITTED'),
      overdue: n('OVERDUE'),
      classSubmitRate: classAverage(classSize, classSubmissions, classSize * assignments.length),
      items,
    };
  }
}
