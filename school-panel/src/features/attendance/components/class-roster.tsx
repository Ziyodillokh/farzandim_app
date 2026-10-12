'use client';

import { History, Lock, PencilLine } from 'lucide-react';
import { useMemo } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { AttendanceBadge } from '@/components/common/status-badges';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import type { AttendanceStatus } from '@/data/contracts';
import type { StudentDayRow } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';
import { initials } from '@/lib/utils';
import { QuickMark } from './quick-mark';
import { SourceTag } from './source-tag';

export type RosterRow = StudentDayRow & { no: number };

/** Belgilangan holat — o'zgartirish huquqi yo'q (navbatchi): faqat qulf belgisi. */
function LockedMark() {
  const { t } = useI18n();
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span className="inline-flex cursor-help items-center gap-1.5 rounded-full bg-white/50 px-2.5 py-1 text-xs text-muted-foreground ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]">
          <Lock className="h-3.5 w-3.5" />
          {t('attendance.classPage.locked')}
        </span>
      </TooltipTrigger>
      <TooltipContent className="max-w-xs">{t('attendance.classPage.lockedHint')}</TooltipContent>
    </Tooltip>
  );
}
export type RosterMode = 'mark' | 'correct' | 'view';

function CorrectedBadge({ row }: { row: RosterRow }) {
  const { t } = useI18n();
  const last = row.record?.corrections.at(-1);
  if (!last) return null;
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Badge variant="default" size="sm" className="cursor-help gap-1">
          <History className="h-3 w-3" />
          {t('attendance.classPage.correctedBadge')}
        </Badge>
      </TooltipTrigger>
      <TooltipContent className="max-w-xs">
        {t('attendance.classPage.lastCorrection', {
          from: t(`enums.attendanceStatus.${last.from}`),
          to: t(`enums.attendanceStatus.${last.to}`),
          reason: last.reason,
        })}
      </TooltipContent>
    </Tooltip>
  );
}

/** Sinf ro'yxati: holat, kirish/chiqish vaqti, manba va belgilash/tuzatish. */
export function ClassRoster({
  rows,
  loading,
  mode,
  busy,
  canChange,
  onMark,
  onCorrect,
}: {
  rows: RosterRow[] | undefined;
  loading?: boolean;
  mode: RosterMode;
  busy?: boolean;
  /** Mavjud holatni o'zgartirish (tuzatish) huquqi. Yo'q bo'lsa faqat kutilayotganlar belgilanadi. */
  canChange: boolean;
  onMark: (row: RosterRow, status: AttendanceStatus) => void;
  onCorrect: (row: RosterRow) => void;
}) {
  const { t } = useI18n();

  const columns = useMemo<Column<RosterRow>[]>(() => {
    const base: Column<RosterRow>[] = [
      { key: 'no', header: t('attendance.classPage.columns.no'), className: 'w-10 tabular-nums text-muted-foreground', cell: (r) => r.no },
      {
        key: 'student',
        header: t('attendance.classPage.columns.student'),
        cell: (r) => (
          <div className="flex items-center gap-3">
            <Avatar className="h-9 w-9 no-print">
              <AvatarFallback className="bg-gradient-to-br from-brand-400 to-brand-800 text-2xs font-semibold text-white">{initials(r.name)}</AvatarFallback>
            </Avatar>
            <div className="min-w-0">
              <p className="truncate font-medium">{r.name}</p>
              <p className="text-xs text-muted-foreground">
                {r.studentCode}
                {r.device === 'NONE' && ` · ${t('enums.device.NONE')}`}
              </p>
            </div>
          </div>
        ),
      },
      {
        key: 'status',
        header: t('attendance.classPage.columns.status'),
        cell: (r) => (
          <div className="flex flex-wrap items-center gap-1.5">
            <AttendanceBadge status={r.record?.status ?? null} />
            <CorrectedBadge row={r} />
          </div>
        ),
      },
      { key: 'in', header: t('attendance.classPage.columns.in'), className: 'font-medium tabular-nums', cell: (r) => r.record?.inAt ?? <span className="text-muted-foreground/60">—</span> },
      { key: 'out', header: t('attendance.classPage.columns.out'), className: 'font-medium tabular-nums', cell: (r) => r.record?.outAt ?? <span className="text-muted-foreground/60">—</span> },
      {
        key: 'source',
        header: t('attendance.classPage.columns.source'),
        cell: (r) => (r.record?.inAt ? <SourceTag source={r.record.source} /> : <span className="text-muted-foreground/60">—</span>),
      },
    ];
    if (mode === 'view') return base;
    const actions: Column<RosterRow> = {
      key: 'actions',
      header: t('attendance.classPage.columns.actions'),
      headerClassName: 'no-print',
      className: 'no-print text-right',
      cell: (r) =>
        mode === 'mark' ? (
          r.record && !canChange ? (
            <LockedMark />
          ) : (
            <QuickMark current={r.record?.status ?? null} disabled={busy} onSelect={(status) => onMark(r, status)} />
          )
        ) : (
          <Button variant="outline" size="sm" disabled={!r.record} onClick={() => onCorrect(r)}>
            <PencilLine />
            {t('attendance.classPage.correct')}
          </Button>
        ),
    };
    return [...base, actions];
  }, [t, mode, busy, canChange, onMark, onCorrect]);

  return <DataTable columns={columns} rows={rows} rowKey={(r) => r.studentId} loading={loading} skeletonRows={10} />;
}
