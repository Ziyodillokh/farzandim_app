'use client';

import { CalendarOff, GraduationCap, Info } from 'lucide-react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useCallback, useMemo, useState } from 'react';

import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { PageHeader } from '@/components/common/page-header';
import { SearchInput, Toolbar } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import type { AttendanceStatus, IsoDate } from '@/data/contracts';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';
import { matchesSearch } from '@/lib/normalize-search';
import { useClassDay, useMarkAttendance } from '../hooks';
import { EMPTY_COUNTS, fromIsoDate, parseDateParam, useClockToday, type StatusKey } from '../lib';
import { ClassRoster, type RosterMode, type RosterRow } from './class-roster';
import { ClassSummary } from './class-summary';
import { CorrectionDialog } from './correction-dialog';
import { DateNav } from './date-nav';
import { LiveIndicator } from './live-indicator';
import { PageSkeleton } from './page-skeleton';

type PendingChange = { row: RosterRow; to: AttendanceStatus };

function countRows(rows: readonly RosterRow[]) {
  return rows.reduce(
    (acc, r) => {
      const s = r.record?.status;
      return {
        present: acc.present + (s === 'PRESENT' ? 1 : 0),
        late: acc.late + (s === 'LATE' ? 1 : 0),
        absent: acc.absent + (s === 'ABSENT' ? 1 : 0),
        leftEarly: acc.leftEarly + (s === 'LEFT_EARLY' ? 1 : 0),
        excused: acc.excused + (s === 'EXCUSED' ? 1 : 0),
        pending: acc.pending + (s ? 0 : 1),
        total: acc.total + 1,
      };
    },
    { ...EMPTY_COUNTS },
  );
}

/** Bitta sinfning kunlik davomati: belgilash (bugun), tuzatish (o'tgan kun), filtr, eksport. */
export function ClassView() {
  const { t, formatDate } = useI18n();
  const can = useCan();
  const router = useRouter();
  const params = useSearchParams();
  const today = useClockToday();
  const school = useSchool();
  const classId = params.get('id');
  const canHistory = can('attendance.history');
  const date = canHistory ? parseDateParam(params.get('date'), today) : undefined;
  const day: IsoDate = date ?? today;
  const query = useClassDay(classId, date);
  const mark = useMarkAttendance();
  const [statusFilter, setStatusFilter] = useState<StatusKey>();
  const [search, setSearch] = useState('');
  const [change, setChange] = useState<PendingChange | null>(null);
  const [correcting, setCorrecting] = useState<RosterRow | null>(null);

  const data = query.data;
  const allRows = useMemo<RosterRow[] | undefined>(() => data?.rows.map((r, i) => ({ ...r, no: i + 1 })), [data]);
  const counts = useMemo(() => countRows(allRows ?? []), [allRows]);
  const rows = useMemo(
    () =>
      allRows?.filter(
        (r) =>
          (!statusFilter || (r.record?.status ?? 'PENDING') === statusFilter) &&
          matchesSearch(`${r.name} ${r.studentCode}`, search),
      ),
    [allRows, statusFilter, search],
  );

  const mode: RosterMode =
    !data?.schoolDay ? 'view' : !date && can('attendance.mark') ? 'mark' : date && can('attendance.correct') ? 'correct' : 'view';

  // Mavjud holatni o'zgartirish — tuzatish huquqi (servis ham tekshiradi).
  const canChange = can('attendance.correct');
  const markNow = mark.mutate; // TanStack: `mutate` barqaror — jadval ustunlari qayta qurilmaydi
  const onMark = useCallback(
    (row: RosterRow, to: AttendanceStatus) => {
      if (!row.record) markNow({ studentId: row.studentId, status: to });
      else if (canChange && row.record.status !== to) setChange({ row, to });
    },
    [markNow, canChange],
  );
  const onCorrect = useCallback((row: RosterRow) => setCorrecting(row), []);

  const setDate = (next: IsoDate) => {
    const suffix = next >= today ? '' : `&date=${next}`;
    router.replace(`/attendance/class?id=${classId ?? ''}${suffix}`, { scroll: false });
  };

  const exportCsv = () => {
    if (!data || !allRows) return;
    downloadCsv(t('attendance.classPage.exportFile', { className: data.className, date: day }), allRows, [
      { header: t('attendance.classPage.columns.no'), value: (r) => r.no },
      { header: t('common.fullName'), value: (r) => r.name },
      { header: t('students.code'), value: (r) => r.studentCode },
      { header: t('attendance.classPage.columns.status'), value: (r) => (r.record ? t(`enums.attendanceStatus.${r.record.status}`) : t('attendance.pending')) },
      { header: t('attendance.classPage.columns.in'), value: (r) => r.record?.inAt },
      { header: t('attendance.classPage.columns.out'), value: (r) => r.record?.outAt },
      { header: t('attendance.classPage.columns.source'), value: (r) => (r.record?.inAt ? t(`enums.attendanceSource.${r.record.source}`) : '') },
    ]);
  };

  if (!classId) {
    return <EmptyState icon={<GraduationCap />} title={t('attendance.classPage.missingId')} description={t('attendance.classPage.missingIdHint')} />;
  }
  if (query.isLoading && !data) return <PageSkeleton />;

  const backHref = date ? `/attendance?date=${date}` : '/attendance';
  const dateLabel = formatDate(fromIsoDate(day), 'd MMMM yyyy, EEEE');

  return (
    <>
      <PageHeader
        backHref={backHref}
        backLabel={t('attendance.classPage.back')}
        title={data ? t('attendance.classPage.title', { className: data.className }) : t('attendance.title')}
        subtitle={data ? `${dateLabel} · ${data.shiftName}` : undefined}
        badge={!date && data?.schoolDay ? <LiveIndicator /> : mode === 'view' && data?.schoolDay ? <Badge variant="secondary">{t('attendance.classPage.readOnly')}</Badge> : undefined}
        actions={
          <>
            <DateNav value={day} today={today} onChange={setDate} canHistory={canHistory} />
            <ExportMenu onCsv={exportCsv} disabled={!data} />
          </>
        }
      />

      {query.error ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : data && !data.schoolDay ? (
        <EmptyState icon={<CalendarOff />} title={t('attendance.noSchoolDay')} description={t('attendance.noSchoolDayHint')} />
      ) : (
        <>
          <div className="print-only mb-4">
            <p className="text-lg font-semibold">{school.data?.school.name}</p>
            <p className="text-sm">
              {t('attendance.classPage.printMeta', { date: dateLabel, shift: data?.shiftName ?? '', printed: formatDate(new Date(), 'dd.MM.yyyy HH:mm') })}
            </p>
          </div>
          {mode === 'correct' && (
            <p className="mb-4 flex items-center gap-2 rounded-lg border border-info/25 bg-info/10 px-3 py-2 text-sm text-info no-print">
              <Info className="h-4 w-4 shrink-0" />
              {t('attendance.classPage.pastHint')}
            </p>
          )}
          <ClassSummary counts={counts} value={statusFilter} onChange={setStatusFilter} />
          <Toolbar>
            <SearchInput value={search} onChange={setSearch} placeholder={t('attendance.classPage.searchPlaceholder')} />
          </Toolbar>
          <ClassRoster rows={rows} loading={query.isLoading} mode={mode} busy={mark.isPending} canChange={canChange} onMark={onMark} onCorrect={onCorrect} />
        </>
      )}

      <ConfirmDialog
        key={change ? `${change.row.studentId}:${change.to}` : 'none'}
        open={Boolean(change)}
        onOpenChange={(open) => !open && setChange(null)}
        title={t('attendance.classPage.changeTitle')}
        description={
          change?.row.record
            ? t('attendance.classPage.changeText', {
                name: change.row.name,
                from: t(`enums.attendanceStatus.${change.row.record.status}`),
                to: t(`enums.attendanceStatus.${change.to}`),
              })
            : undefined
        }
        requireReason
        loading={mark.isPending}
        onConfirm={(reason) => {
          if (!change) return;
          mark.mutate({ studentId: change.row.studentId, status: change.to, reason }, { onSuccess: () => setChange(null) });
        }}
      />
      <CorrectionDialog row={correcting} date={day} onClose={() => setCorrecting(null)} />
    </>
  );
}
