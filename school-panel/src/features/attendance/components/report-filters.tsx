'use client';

import { CalendarRange, GraduationCap } from 'lucide-react';
import { useMemo } from 'react';

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { ClassOption } from '@/data/mock/services/attendance';
import { useI18n } from '@/i18n';

const MONTHS_BACK = 12;

/** Oxirgi 12 oy ("2026-10", "2026-09", …). */
export function recentMonths(current: string): string[] {
  const [y, m] = current.split('-').map(Number);
  return Array.from({ length: MONTHS_BACK }, (_, i) => {
    const d = new Date(y ?? 2026, (m ?? 1) - 1 - i, 1);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  });
}

export function monthDate(month: string): Date {
  const [y, m] = month.split('-').map(Number);
  return new Date(y ?? 2026, (m ?? 1) - 1, 1);
}

/** Hisobot filtrlari: oy va sinf. */
export function ReportFilters({
  month,
  currentMonth,
  onMonthChange,
  classId,
  classes,
  onClassChange,
}: {
  month: string;
  currentMonth: string;
  onMonthChange: (month: string) => void;
  classId: string | undefined;
  classes: ClassOption[] | undefined;
  onClassChange: (classId: string) => void;
}) {
  const { t, formatDate } = useI18n();
  const months = useMemo(() => recentMonths(currentMonth), [currentMonth]);

  return (
    <div className="mb-6 flex flex-wrap items-center gap-2 no-print">
      <Select value={month} onValueChange={onMonthChange}>
        <SelectTrigger className="w-full sm:w-52" aria-label={t('attendance.reports.month')}>
          <span className="flex items-center gap-2">
            <CalendarRange className="h-4 w-4 text-primary" />
            <SelectValue />
          </span>
        </SelectTrigger>
        <SelectContent>
          {months.map((m) => (
            <SelectItem key={m} value={m} className="capitalize">
              {formatDate(monthDate(m), 'LLLL yyyy')}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Select value={classId ?? ''} onValueChange={onClassChange} disabled={!classes?.length}>
        <SelectTrigger className="w-full sm:w-44" aria-label={t('attendance.reports.class')}>
          <span className="flex items-center gap-2">
            <GraduationCap className="h-4 w-4 text-primary" />
            <SelectValue placeholder={t('attendance.reports.selectClass')} />
          </span>
        </SelectTrigger>
        <SelectContent>
          {classes?.map((c) => (
            <SelectItem key={c.id} value={c.id}>
              {c.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
