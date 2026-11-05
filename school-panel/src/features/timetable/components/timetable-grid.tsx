'use client';

import { DoorOpen, Plus, UserRound } from 'lucide-react';
import { type KeyboardEvent, useRef, useState } from 'react';

import type { BellPeriod, TimetableWeekday } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { type CellErrorKind, type CellValue, cellKey, type Direction, type Grid, neighborCell, WEEKDAYS } from '../lib/grid';
import { subjectLabel, subjectTint } from '../lib/subject';

const ARROWS: Record<string, Direction> = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' };

type Props = {
  /** Smenaning faqat DARS davrlari. */
  periods: readonly BellPeriod[];
  grid: Grid;
  /** Katak kaliti → xato turi (saqlashdan keyin). */
  errors: Readonly<Record<string, CellErrorKind>>;
  readOnly: boolean;
  className: string;
  onEdit: (weekday: TimetableWeekday, period: BellPeriod) => void;
};

/**
 * Hafta × dars davrlari to'ri. Tahrirlash rejimida ARIA `grid`: bitta Tab to'xtash joyi (roving tabindex),
 * strelkalar bilan yurish, Enter/Space — katakni ochish. Faqat ko'rish rejimida oddiy jadval.
 */
export function TimetableGrid({ periods, grid, errors, readOnly, className, onEdit }: Props) {
  const { t } = useI18n();
  const tableRef = useRef<HTMLTableElement>(null);
  const periodNos = periods.map((p) => p.no);
  const firstKey = periods[0] ? cellKey(WEEKDAYS[0] ?? 1, periods[0].no) : '';
  const [activeKey, setActiveKey] = useState(firstKey);
  const tabbableKey = activeKey && periodNos.includes(Number(activeKey.split(':')[1])) ? activeKey : firstKey;

  const onKeyDown = (event: KeyboardEvent<HTMLTableElement>) => {
    const direction = ARROWS[event.key];
    const current = event.target instanceof HTMLElement ? event.target.dataset.cell : undefined;
    if (!direction || !current) return;
    const next = neighborCell(current, direction, periodNos);
    event.preventDefault();
    if (!next) return;
    setActiveKey(next);
    tableRef.current?.querySelector<HTMLElement>(`[data-cell="${next}"]`)?.focus();
  };

  return (
    <div className="overflow-x-auto pb-1">
      <table
        ref={tableRef}
        role={readOnly ? undefined : 'grid'}
        aria-label={t('timetable.tableCaption', { class: className })}
        onKeyDown={readOnly ? undefined : onKeyDown}
        className="w-full min-w-[820px] table-fixed border-separate border-spacing-1.5"
      >
        <thead>
          <tr>
            <th scope="col" className="w-32 text-left text-2xs font-semibold uppercase tracking-wider text-muted-foreground">
              <span className="sr-only">{t('timetable.periodColumn')}</span>
            </th>
            {WEEKDAYS.map((day) => (
              <th key={day} scope="col" className="px-1 pb-1 text-center text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                {t(`enums.weekday.${day}`)}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {periods.map((period) => (
            <tr key={period.no}>
              <th scope="row" className="pr-2 text-left align-middle">
                <span className="block text-sm font-semibold">{t('timetable.lessonNo', { no: period.no })}</span>
                <span className="block text-xs font-normal tabular-nums text-muted-foreground">
                  {period.start}–{period.end}
                </span>
              </th>
              {WEEKDAYS.map((day) => {
                const key = cellKey(day, period.no);
                return (
                  <td key={day} role={readOnly ? undefined : 'gridcell'} className="h-[4.75rem] p-0 align-top">
                    <Cell
                      cellId={key}
                      weekday={day}
                      period={period}
                      value={grid[key]}
                      error={errors[key]}
                      readOnly={readOnly}
                      tabbable={key === tabbableKey}
                      onFocus={() => setActiveKey(key)}
                      onEdit={() => onEdit(day, period)}
                    />
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Cell({
  cellId,
  weekday,
  period,
  value,
  error,
  readOnly,
  tabbable,
  onFocus,
  onEdit,
}: {
  cellId: string;
  weekday: TimetableWeekday;
  period: BellPeriod;
  value: CellValue | undefined;
  error: CellErrorKind | undefined;
  readOnly: boolean;
  tabbable: boolean;
  onFocus: () => void;
  onEdit: () => void;
}) {
  const { t } = useI18n();
  const subject = value?.subject ?? '';
  const filled = subject !== '';
  const errorText = error ? t(`timetable.errors.${error}`) : null;
  const where = `${t(`enums.weekday.${weekday}`)}, ${t('timetable.lessonNo', { no: period.no })} (${period.start}–${period.end})`;
  const what = filled ? [subjectLabel(t, subject), value?.room, value?.teacherName].filter(Boolean).join(', ') : t('timetable.empty');
  const label = `${where}: ${what}${errorText ? `. ${errorText}` : ''}`;

  const body = filled ? (
    <>
      <span className="line-clamp-2 text-sm font-semibold leading-tight">{subjectLabel(t, subject)}</span>
      {value?.room && (
        <span className="flex max-w-full items-center gap-1 text-2xs text-muted-foreground">
          <DoorOpen className="h-3 w-3 shrink-0" aria-hidden />
          <span className="truncate">{value.room}</span>
        </span>
      )}
      {value?.teacherName && (
        <span className="flex max-w-full items-center gap-1 text-2xs text-muted-foreground">
          <UserRound className="h-3 w-3 shrink-0" aria-hidden />
          <span className="truncate">{value.teacherName}</span>
        </span>
      )}
    </>
  ) : readOnly ? (
    <span className="text-xs text-muted-foreground/60">—</span>
  ) : (
    <Plus className="h-4 w-4 text-muted-foreground/50 transition-opacity group-hover:text-primary" aria-hidden />
  );

  const frame = cn(
    'flex h-full min-h-[4.5rem] w-full flex-col justify-center gap-0.5 rounded-xl px-2.5 py-2 text-left ring-1 ring-inset',
    filled ? subjectTint(subject) : 'items-center bg-transparent ring-border/50',
    error && 'ring-2 ring-destructive',
  );

  if (readOnly) {
    return (
      <div className={frame} aria-label={label} role="group">
        {body}
        {errorText && <span className="text-2xs font-medium text-destructive">{errorText}</span>}
      </div>
    );
  }
  return (
    <button
      type="button"
      data-cell={cellId}
      tabIndex={tabbable ? 0 : -1}
      aria-label={label}
      onFocus={onFocus}
      onClick={onEdit}
      className={cn(
        frame,
        'group transition-colors hover:ring-primary/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
        !filled && 'border border-dashed border-transparent hover:bg-primary/[0.04]',
      )}
    >
      {body}
      {errorText && <span className="text-2xs font-medium text-destructive">{errorText}</span>}
    </button>
  );
}
