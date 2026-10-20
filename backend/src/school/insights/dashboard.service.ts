// Bosh sahifa (panel `dashboardService.overview`): rolga mos bo'limlar —
// ruxsat bo'lmagan bo'lim `null`. Raqamlar tegishli modul servislaridan
// (davomat taxtasi, School Mode, Bola ovozi, ota-onalar) — sahifalar bilan mos.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { AttendanceBoardService } from '../attendance/attendance-board.service';
import { attendedRate, DayCounts } from '../attendance/attendance-view';
import { actorCan, allowedClassIds, classScopeWhere, SchoolActor } from '../auth/school-actor';
import { CareInsightsService } from '../care/care-insights.service';
import { compareUz } from '../common/list-query';
import { audienceTouchesScope, loadRoster, toAudience } from '../comms/comms-roster';
import { nextOccurrence, RepeatKind, toLocalDateTime } from '../comms/comms-time';
import { SchoolModeReadsService } from '../school-mode/school-mode-reads.service';
import { isSchoolDay, tashkentMinute } from '../school-mode/school-mode-time';
import { toShiftLike } from '../school-mode/school-mode-store';
import { GuardiansService } from '../students/guardians.service';
import { NotificationsService } from './notifications.service';

const RECENT_REQUESTS = 5;
const UPCOMING_LIMIT = 5;
const SAFETY_WINDOW_MS = 24 * 3_600_000;

type Tone = 'destructive' | 'warning' | 'info';
type Alert = { kind: string; count: number; href: string; tone: Tone };

@Injectable()
export class DashboardService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly board: AttendanceBoardService,
    private readonly schoolMode: SchoolModeReadsService,
    private readonly guardians: GuardiansService,
    private readonly careInsights: CareInsightsService,
    private readonly notifications: NotificationsService,
  ) {}

  async overview(actor: SchoolActor) {
    const can = (p: Parameters<typeof actorCan>[1]) => actorCan(actor, p);
    const now = new Date();
    const today = tashkentDay(now);
    const [schoolDay, attendance, schoolMode, parents, open, care, careInbox, upcoming, safety] = await Promise.all([
      this.schoolDay(actor, today),
      can('attendance.view') ? this.attendance(actor) : null,
      can('schoolMode.view') ? this.schoolModeSummary(actor) : null,
      can('students.view') && !can('care.individual') ? this.guardians.linkSummary(actor) : null,
      can('attendance.view') ? this.openRequests(actor) : null,
      can('care.aggregate') ? this.care(actor) : null,
      can('care.individual') ? this.careInbox(actor, today) : null,
      can('messages.view') ? this.upcoming(actor, now) : null,
      this.prisma.schoolStaffNotification.count({
        where: { ...this.notifications.storedWhere(actor), kind: 'SAFETY_SIGNAL', at: { gte: new Date(now.getTime() - SAFETY_WINDOW_MS), lte: now } },
      }),
    ]);
    return {
      date: today,
      minute: tashkentMinute(now),
      role: actor.role,
      actorName: actor.name,
      schoolDay,
      attendance: attendance?.kpi ?? null,
      classes: attendance?.rows ?? null,
      schoolMode,
      parents,
      openRequests: open,
      // Rivojlanish (psixologik testlar) va maktab Growth — tegishli modullar ulanganda.
      development: null,
      alerts: await this.alerts(actor, { safety, absent: attendance?.kpi.counts.absent ?? null, schoolMode, open, careInbox }),
      upcoming,
      care,
      careInbox: careInbox?.view ?? null,
      learning: null,
    };
  }

  /** Doiradagi sinflardan kamida bittasi uchun bugun o'quv kunimi. */
  private async schoolDay(actor: SchoolActor, today: string): Promise<boolean> {
    const allowed = allowedClassIds(actor);
    const [classes, holidays] = await Promise.all([
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId, ...(allowed && { id: { in: allowed } }) }, select: { shift: true } }),
      this.prisma.schoolHoliday.findMany({ where: { schoolId: actor.schoolId, date: today } }),
    ]);
    return classes.some((c) => isSchoolDay(today, toShiftLike(c.shift), holidays));
  }

  /** Bugungi davomat: qiymat va chiziq bir xil asosda — kelganlar / aniqlanganlar. */
  private async attendance(actor: SchoolActor) {
    const board = await this.board.board(actor, {});
    const counts: DayCounts = board.totals;
    const decided = counts.total - counts.pending;
    const rows = board.rows
      .filter((r) => r.schoolDay)
      .sort((a, b) => compareUz(a.className, b.className))
      .map((r) => ({
        classId: r.classId,
        className: r.className,
        rate: r.rate,
        arrived: r.counts.present + r.counts.late + r.counts.leftEarly,
        total: r.counts.total,
        late: r.counts.late,
        absent: r.counts.absent,
      }));
    return {
      kpi: { counts, rate: decided > 0 ? attendedRate(counts) : null, arrived: counts.present + counts.late + counts.leftEarly, decided },
      rows,
    };
  }

  private async schoolModeSummary(actor: SchoolActor) {
    const overview = await this.schoolMode.overview(actor);
    const { APPLIED, NO_PERMISSION, NO_PHONE, OFFLINE } = overview.totals.devices;
    return {
      restrictedClasses: overview.totals.restrictedClasses,
      activeClasses: overview.classes.filter((c) => c.state.kind === 'LESSON' || c.state.kind === 'BREAK').length,
      emergency: overview.emergency.active,
      devices: { APPLIED, NO_PERMISSION, NO_PHONE, OFFLINE },
      activeExceptions: overview.totals.activeExceptions,
    };
  }

  /** Rolga mos "ochiq so'rovlar": erta ketish + to'lov tekshiruvlari. */
  private async openRequests(actor: SchoolActor) {
    const [earlyExits, verifications] = await Promise.all([
      this.prisma.schoolEarlyExit.count({ where: { schoolId: actor.schoolId, status: 'PENDING', ...classScopeWhere(actor) } }),
      actorCan(actor, 'payments.manage') ? this.prisma.schoolVerificationRequest.count({ where: { schoolId: actor.schoolId, status: 'OPEN' } }) : null,
    ]);
    const href = earlyExits === 0 && (verifications ?? 0) > 0 ? '/reminders/verifications' : '/attendance/early-exit';
    return { earlyExits, verifications, total: earlyExits + (verifications ?? 0), href };
  }

  /** /care bilan bir xil hisob (maktab kesimi) — raqamlar mos tushadi. */
  private async care(actor: SchoolActor) {
    try {
      const agg = await this.careInsights.aggregate(actor, { breakdown: 'SCHOOL' });
      return { participation: agg.participationRate, wellbeing: agg.overall.WELLBEING ?? null, requestsThisWeek: agg.requestsThisWeek };
    } catch {
      return null; // hali so'rovnoma yo'q
    }
  }

  /** Murojaatlar qutisi — faqat psixolog (ism bor, matn yo'q). */
  private async careInbox(actor: SchoolActor, today: string) {
    const open = await this.prisma.schoolCareRequest.findMany({ where: { schoolId: actor.schoolId, status: { not: 'RESOLVED' } } });
    const recent = [...open]
      .sort((a, b) => (a.urgency === b.urgency ? b.createdAt.getTime() - a.createdAt.getTime() : a.urgency === 'URGENT' ? -1 : 1))
      .slice(0, RECENT_REQUESTS);
    const [students, classes] = await Promise.all([
      this.prisma.schoolStudent.findMany({ where: { id: { in: recent.map((r) => r.studentId) } }, select: { id: true, lastName: true, firstName: true } }),
      this.prisma.schoolClass.findMany({ where: { schoolId: actor.schoolId }, select: { id: true, name: true } }),
    ]);
    const studentName = new Map(students.map((s) => [s.id, `${s.lastName} ${s.firstName}`]));
    const className = new Map(classes.map((c) => [c.id, c.name]));
    const view = {
      newCount: open.filter((r) => r.status === 'NEW').length,
      urgentOpen: open.filter((r) => r.urgency === 'URGENT').length,
      inProgress: open.filter((r) => r.status === 'IN_PROGRESS' || r.status === 'SCHEDULED').length,
      meetingsToday: open.filter((r) => r.meetingAt && tashkentDay(r.meetingAt) === today).length,
      recent: recent.map((r) => ({
        id: r.id,
        studentName: studentName.get(r.studentId) ?? '—',
        className: (r.classId && className.get(r.classId)) || '',
        topic: r.topic,
        urgency: r.urgency,
        status: r.status,
        createdAt: r.createdAt.toISOString(),
      })),
    };
    return { view, urgent: view.urgentOpen, fresh: view.newCount };
  }

  private async upcoming(actor: SchoolActor, now: Date) {
    const reminders = await this.prisma.schoolReminder.findMany({ where: { schoolId: actor.schoolId, active: true } });
    const roster = allowedClassIds(actor) ? await loadRoster(this.prisma, actor.schoolId) : null;
    return reminders
      .filter((r) => !roster || audienceTouchesScope(actor, roster, toAudience(r.audience)))
      .flatMap((r) => {
        const next = nextOccurrence(r.sendAt, r.repeat as RepeatKind, now);
        return next ? [{ r, next }] : [];
      })
      .sort((a, b) => a.next.getTime() - b.next.getTime())
      .slice(0, UPCOMING_LIMIT)
      .map(({ r, next }) => ({ id: r.id, kind: r.kind, title: r.title, sendAt: toLocalDateTime(next) }));
  }

  private async alerts(
    actor: SchoolActor,
    input: {
      safety: number;
      absent: number | null;
      schoolMode: { emergency: boolean; devices: { NO_PERMISSION: number } } | null;
      open: { earlyExits: number; verifications: number | null } | null;
      careInbox: { urgent: number; fresh: number } | null;
    },
  ): Promise<Alert[]> {
    const alerts: Alert[] = [];
    const push = (kind: string, count: number, href: string, tone: Tone) => {
      if (count > 0) alerts.push({ kind, count, href, tone });
    };
    if (input.schoolMode?.emergency) push('EMERGENCY', 1, '/school-mode', 'destructive');
    const safetyHref = actorCan(actor, 'care.aggregate') ? '/care' : actorCan(actor, 'attendance.view') ? '/attendance' : '/dashboard';
    push('SAFETY_SIGNAL', input.safety, safetyHref, 'destructive');
    if (input.careInbox) {
      push('CARE_URGENT', input.careInbox.urgent, '/care/requests', 'destructive');
      push('CARE_NEW', input.careInbox.fresh, '/care/requests', 'info');
    }
    if (actorCan(actor, 'attendance.earlyExit') && input.open) push('EARLY_EXIT', input.open.earlyExits, '/attendance/early-exit', 'warning');
    if (input.absent !== null) push('ABSENT', input.absent, '/attendance', 'warning');
    if (input.open?.verifications) push('VERIFICATION', input.open.verifications, '/reminders/verifications', 'info');
    if (input.schoolMode) push('NO_PERMISSION', input.schoolMode.devices.NO_PERMISSION, '/school-mode', 'info');
    return alerts;
  }
}
