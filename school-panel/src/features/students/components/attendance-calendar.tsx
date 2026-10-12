'use client';

import { ChevronLeft, ChevronRight } from 'lucide-react';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import type { AttendanceStatus } from '@/data/contracts';
import { fromIsoDate, isoWeekday } from '@/data/mock/calendar';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useStudentMonth } from '../hooks';

const CELL: Record<AttendanceStatus, string> = {
  PRESENT: 'bg-success/15 text-success border-success/30',
  LATE: 'bg-warning/15 text-warning border-warning/40',
  ABSENT: 'bg-destructive/10 text-destructive border-destructive/30',
  LEFT_EARLY: 'bg-info/10 text-info border-info/30',
  EXCUSED: 'bg-muted text-muted-foreground border-border',
};

function shiftMonth(month: string, delta: number): string {
  const [y, m] = month.split('-').map(Number);
  const d = new Date(y ?? 2026, (m ?? 1) - 1 + delta, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

/** O'quvchining oylik davomat kalendari. */
export function AttendanceCalendar({ studentId, initialMonth }: { studentId: string; initialMonth: string }) {
  const { t, formatDate } = useI18n();
  const [month, setMonth] = useState(initialMonth);
  const days = useStudentMonth(studentId, month);
  const first = fromIsoDate(`${month}-01`);
  const lead = isoWeekday(`${month}-01`) - 1;

  return (
    <div>
      <div className="mb-3 flex items-center justify-between">
        <p className="font-semibold capitalize">{formatDate(first, 'LLLL yyyy')}</p>
        <div className="flex gap-1">
          <Button variant="outline" size="icon-sm" onClick={() => setMonth((m) => shiftMonth(m, -1))} aria-label="prev">
            <ChevronLeft />
          </Button>
          <Button variant="outline" size="icon-sm" onClick={() => setMonth((m) => shiftMonth(m, 1))} disabled={month >= initialMonth} aria-label="next">
            <ChevronRight />
          </Button>
        </div>
      </div>
      <div className="grid grid-cols-7 gap-1.5 text-center text-2xs font-semibold uppercase text-muted-foreground">
        {([1, 2, 3, 4, 5, 6, 7] as const).map((d) => (
          <span key={d}>{t(`enums.weekdayShort.${d}`)}</span>
        ))}
      </div>
      <div className="mt-1.5 grid grid-cols-7 gap-1.5">
        {Array.from({ length: lead }).map((_, i) => (
          <span key={`lead-${i}`} />
        ))}
        {days.isLoading
          ? Array.from({ length: 30 }).map((_, i) => <Skeleton key={i} className="h-11 rounded-lg sm:h-12" />)
          : days.data?.map(({ date, record }) => {
              const day = Number(date.slice(8));
              const status = record?.status;
              return (
                <div
                  key={date}
                  title={status ? `${date} · ${t(`enums.attendanceStatus.${status}`)}${record?.inAt ? ` · ${record.inAt}` : ''}` : date}
                  className={cn(
                    'flex h-11 flex-col items-center justify-center rounded-lg border text-xs font-semibold tabular-nums sm:h-12',
                    status ? CELL[status] : 'border-dashed border-border/60 text-muted-foreground/50',
                  )}
                >
                  {day}
                </div>
              );
            })}
      </div>
      <div className="mt-4 flex flex-wrap gap-3 text-xs text-muted-foreground">
        {(Object.keys(CELL) as AttendanceStatus[]).map((s) => (
          <span key={s} className="inline-flex items-center gap-1.5">
            <span className={cn('h-3 w-3 rounded border', CELL[s])} />
            {t(`enums.attendanceStatus.${s}`)}
          </span>
        ))}
      </div>
    </div>
  );
}
