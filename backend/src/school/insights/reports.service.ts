// Oylik umumiy hisobot (panel `reportsService.monthly`) — direktor /
// administrator (`reports.view`, butun maktab). Bo'lim ruxsat bo'lmasa — null.
// Faqat haqiqiy yozuvlardan; bugun hisobga olinmaydi (kun hali tugamagan).

import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { PrismaService } from '../../common/database/prisma.service';
import { addDays, isoWeekday, tashkentDay, tashkentDayStart } from '../../common/time/tashkent';
import { actorCan, assertCan, SchoolActor } from '../auth/school-actor';
import { CareInsightsService } from '../care/care-insights.service';
import { CARE_MIN_GROUP, maskSmallCount } from '../care/care-suppression';
import { deviceChildSelect, deviceStateOf } from '../common/device-state';
import { compareClasses } from '../common/list-query';
import { forbidden } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { toShiftLike } from '../school-mode/school-mode-store';
import { isSchoolDay } from '../school-mode/school-mode-time';

const monthSchema = z.object({ month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, 'errors.form.invalid') });
const percent = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 100) : 0);
const CAME = new Set(['PRESENT', 'LATE', 'LEFT_EARLY']);

function monthBounds(month: string) {
  const [y = 2026, m = 1] = month.split('-').map(Number);
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return { first: `${month}-01`, last: `${month}-${String(last).padStart(2, '0')}` };
}

@Injectable()
export class ReportsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly careInsights: CareInsightsService,
  ) {}

  async monthly(actor: SchoolActor, query: unknown) {
    const { month } = parseOrThrow(monthSchema, query);
    assertCan(actor, 'reports.view');
    if (actor.scope !== 'SCHOOL') throw forbidden('reports.scope');
    const now = new Date();
    const { first, last } = monthBounds(month);
    const yesterday = addDays(tashkentDay(now), -1);
    const until = last < yesterday ? last : yesterday;
    const range = { gte: tashkentDayStart(first), lt: tashkentDayStart(addDays(last, 1)) };
    const days: string[] = [];
    for (let d = first; d <= until; d = addDays(d, 1)) days.push(d);
    const [shifts, holidays] = await Promise.all([
      this.prisma.schoolShift.findMany({ where: { schoolId: actor.schoolId } }),
      this.prisma.schoolHoliday.findMany({ where: { schoolId: actor.schoolId, date: { gte: first, lte: last } } }),
    ]);
    const anyShiftDay = (d: string) => shifts.some((s) => isSchoolDay(d, toShiftLike(s), holidays));
    const can = (p: Parameters<typeof actorCan>[1]) => actorCan(actor, p);
    const [attendance, parents, schoolMode, messages, care] = await Promise.all([
      can('attendance.history') && days.length ? this.attendance(actor.schoolId, first, until) : can('attendance.history') ? this.emptyAttendance() : null,
      can('students.view') ? this.parents(actor.schoolId) : null,
      can('schoolMode.view') ? this.schoolMode(actor.schoolId, range) : null,
      can('messages.view') ? this.messages(actor.schoolId, range, now) : null,
      can('care.aggregate') ? this.care(actor, month, range) : null,
    ]);
    return {
      month,
      until: days.length ? until : null,
      schoolDays: days.filter(anyShiftDay).length,
      generatedAt: now.toISOString(),
      generatedBy: actor.name,
      attendance,
      parents,
      schoolMode,
      messages,
      care,
      learning: null,
    };
  }

  private emptyAttendance() {
    return { rate: 0, late: 0, absent: 0, excused: 0, byClass: [], byWeekday: [] };
  }

  private async attendance(schoolId: string, first: string, until: string) {
    const [classes, rows, students] = await Promise.all([
      this.prisma.schoolClass.findMany({ where: { schoolId }, select: { id: true, name: true, grade: true, letter: true } }),
      this.prisma.schoolAttendance.findMany({ where: { schoolId, date: { gte: first, lte: until } }, select: { classId: true, date: true, status: true } }),
      this.prisma.schoolStudent.groupBy({ by: ['classId'], where: { schoolId, archived: false }, _count: { _all: true } }),
    ]);
    const sizes = new Map(students.map((s) => [s.classId, s._count._all]));
    type Acc = { attended: number; decided: number; late: number; absent: number; excused: number };
    const zero = (): Acc => ({ attended: 0, decided: 0, late: 0, absent: 0, excused: 0 });
    const byClass = new Map<string, Acc>();
    const byWeekday = new Map<number, Acc>();
    const total = zero();
    const slot = <K>(map: Map<K, Acc>, key: K): Acc => {
      const acc = map.get(key) ?? zero();
      map.set(key, acc);
      return acc;
    };
    for (const r of rows) {
      for (const acc of [slot(byClass, r.classId ?? ''), slot(byWeekday, isoWeekday(r.date)), total]) {
        acc.decided += 1;
        if (CAME.has(r.status)) acc.attended += 1;
        if (r.status === 'LATE') acc.late += 1;
        if (r.status === 'ABSENT') acc.absent += 1;
        if (r.status === 'EXCUSED') acc.excused += 1;
      }
    }
    return {
      rate: percent(total.attended, total.decided),
      late: total.late,
      absent: total.absent,
      excused: total.excused,
      byClass: [...classes].sort(compareClasses).map((c) => {
        const acc = byClass.get(c.id) ?? zero();
        return { classId: c.id, className: c.name, students: sizes.get(c.id) ?? 0, rate: percent(acc.attended, acc.decided), late: acc.late, absent: acc.absent, excused: acc.excused };
      }),
      byWeekday: [...byWeekday.entries()].sort(([a], [b]) => a - b).map(([weekday, acc]) => ({ weekday, rate: percent(acc.attended, acc.decided) })),
    };
  }

  private async parents(schoolId: string) {
    const [classes, students] = await Promise.all([
      this.prisma.schoolClass.findMany({ where: { schoolId }, select: { id: true, name: true, grade: true, letter: true } }),
      this.prisma.schoolStudent.findMany({
        where: { schoolId, archived: false },
        select: { classId: true, guardians: { select: { guardian: { select: { linkStatus: true } } } } },
      }),
    ]);
    const byClass = [...classes].sort(compareClasses).map((c) => {
      const own = students.filter((s) => s.classId === c.id);
      const linked = own.filter((s) => s.guardians.some((g) => g.guardian.linkStatus === 'LINKED')).length;
      return { classId: c.id, className: c.name, linked, total: own.length, rate: percent(linked, own.length) };
    });
    const linkedStudents = byClass.reduce((n, r) => n + r.linked, 0);
    return { linkedStudents, totalStudents: students.length, rate: percent(linkedStudents, students.length), byClass };
  }

  private async schoolMode(schoolId: string, range: { gte: Date; lt: Date }) {
    const [students, exceptions, changes] = await Promise.all([
      this.prisma.schoolStudent.findMany({ where: { schoolId, archived: false }, select: { id: true, device: true, child: { select: deviceChildSelect } } }),
      this.prisma.schoolModeException.count({ where: { schoolId, from: range } }),
      this.prisma.schoolAuditLog.count({ where: { schoolId, module: 'SCHOOL_MODE', at: range } }),
    ]);
    const devices = { applied: 0, noPermission: 0, noPhone: 0, offline: 0 };
    for (const s of students) {
      const status = deviceStateOf(s, s.child).status;
      if (status === 'APPLIED') devices.applied += 1;
      else if (status === 'NO_PERMISSION') devices.noPermission += 1;
      else if (status === 'NO_PHONE') devices.noPhone += 1;
      else devices.offline += 1;
    }
    return { ...devices, exceptions, changes };
  }

  private async messages(schoolId: string, range: { gte: Date; lt: Date }, now: Date) {
    const sent = await this.prisma.schoolAnnouncement.findMany({
      where: { schoolId, status: 'SENT', sentAt: range },
      select: { id: true, recipients: true },
    });
    const ids = sent.map((a) => a.id);
    const [delivered, read, reminders] = await Promise.all([
      this.prisma.schoolAnnouncementDelivery.count({ where: { announcementId: { in: ids }, deliveredAt: { not: null } } }),
      this.prisma.schoolAnnouncementDelivery.count({ where: { announcementId: { in: ids }, readAt: { not: null } } }),
      this.prisma.schoolReminder.count({ where: { schoolId, sendAt: { gte: range.gte, lt: range.lt, lte: now } } }),
    ]);
    const recipients = sent.reduce((n, a) => n + a.recipients, 0);
    return {
      announcements: sent.length,
      recipients,
      delivered,
      read,
      deliveryRate: percent(delivered, recipients),
      readRate: percent(read, recipients),
      reminders,
    };
  }

  /** Oy so'rovnomalaridan /care bilan bir xil tanlov (eng so'nggi k ≥ 5 li, bo'lmasa eng so'nggisi). */
  private async care(actor: SchoolActor, month: string, range: { gte: Date; lt: Date }) {
    const surveys = (await this.prisma.schoolCareSurvey.findMany({ where: { schoolId: actor.schoolId, status: { not: 'DRAFT' } } }))
      .filter((s) => s.weekStart.slice(0, 7) === month)
      .sort((a, b) => b.weekStart.localeCompare(a.weekStart));
    const [respondentsBySurvey, requests] = await Promise.all([
      this.prisma.schoolCareResponse.groupBy({ by: ['surveyId'], where: { surveyId: { in: surveys.map((s) => s.id) } }, _count: { _all: true } }),
      this.prisma.schoolCareRequest.count({ where: { schoolId: actor.schoolId, createdAt: range } }),
    ]);
    const counts = new Map(respondentsBySurvey.map((r) => [r.surveyId, r._count._all]));
    const respondents = surveys.reduce((n, s) => n + (counts.get(s.id) ?? 0), 0);
    const invited = surveys.reduce((n, s) => n + s.invited, 0);
    const chosen = surveys.find((s) => (counts.get(s.id) ?? 0) >= CARE_MIN_GROUP) ?? surveys[0];
    const agg = chosen ? await this.careInsights.aggregate(actor, { surveyId: chosen.id, breakdown: 'AGE_GROUP' }) : null;
    return {
      surveys: surveys.length,
      invited,
      respondents,
      participation: percent(respondents, invited),
      wellbeing: agg?.overall.WELLBEING ?? null,
      requests: maskSmallCount(requests),
      groups: (agg?.groups ?? []).map((g) => ({
        key: g.key,
        respondents: g.hidden ? 0 : g.respondents,
        hidden: g.hidden,
        wellbeing: g.hidden ? null : (g.topicScores?.WELLBEING ?? null),
      })),
    };
  }
}
