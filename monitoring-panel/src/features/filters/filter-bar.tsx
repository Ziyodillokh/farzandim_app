'use client';

import { CalendarRange, RotateCcw, School, Users, UsersRound } from 'lucide-react';
import type { ReactNode } from 'react';

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { Filters } from '@/data/contracts';
import { PERIODS } from '@/data/mock/model/calendar';
import { GENDERS, GRADE_BANDS, SCHOOL_TYPES } from '@/data/reference/domains';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { isDefaultFilters, resetFilters, useFilters } from './store';

function FilterSelect<V extends string>({
  label,
  icon,
  value,
  options,
  onChange,
  render,
  className,
}: {
  label: string;
  icon: ReactNode;
  value: V;
  options: readonly V[];
  onChange: (v: V) => void;
  render: (v: V) => string;
  className?: string;
}) {
  return (
    <Select value={value} onValueChange={(v) => onChange(v as V)}>
      <SelectTrigger
        aria-label={label}
        className={cn(
          'h-9 gap-2 rounded-xl border-0 bg-primary/[0.06] px-3 text-[0.8rem] font-medium shadow-none ring-1 ring-inset ring-border/60 hover:ring-primary/40 dark:bg-white/[0.04] [&>svg:last-child]:ml-0.5',
          className,
        )}
      >
        <span className="text-primary [&>svg]:h-3.5 [&>svg]:w-3.5">{icon}</span>
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {options.map((o) => (
          <SelectItem key={o} value={o}>
            {render(o)}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}

/** Global filtrlar: davr, sinf guruhi, jins, maktab turi (hamma sahifalar uchun umumiy). */
export function FilterBar({ className, stacked = false }: { className?: string; stacked?: boolean }) {
  const { t } = useI18n();
  const [filters, setFilters] = useFilters();
  const set = <K extends keyof Filters>(key: K) => (value: Filters[K]) => setFilters({ [key]: value } as Partial<Filters>);
  return (
    <div className={cn('flex items-center gap-1.5', stacked && 'flex-col items-stretch', className)} role="group" aria-label={t('shell.filters')}>
      <FilterSelect label={t('filters.period')} icon={<CalendarRange />} value={filters.period} options={PERIODS} onChange={set('period')} render={(v) => t(`enums.period.${v}`)} className={stacked ? 'w-full' : 'w-auto whitespace-nowrap'} />
      <FilterSelect label={t('filters.grades')} icon={<Users />} value={filters.grades} options={GRADE_BANDS} onChange={set('grades')} render={(v) => t(`enums.gradeBand.${v}`)} className={stacked ? 'w-full' : 'w-auto whitespace-nowrap'} />
      <FilterSelect label={t('filters.gender')} icon={<UsersRound />} value={filters.gender} options={GENDERS} onChange={set('gender')} render={(v) => t(`enums.gender.${v}`)} className={stacked ? 'w-full' : 'w-auto whitespace-nowrap'} />
      <FilterSelect label={t('filters.schoolType')} icon={<School />} value={filters.schoolType} options={['ALL', ...SCHOOL_TYPES] as const} onChange={set('schoolType')} render={(v) => t(`enums.schoolType.${v}`)} className={stacked ? 'w-full' : 'w-auto whitespace-nowrap'} />
      {!isDefaultFilters(filters) && (
        <button
          type="button"
          onClick={resetFilters}
          className="flex h-9 shrink-0 items-center justify-center gap-1.5 rounded-xl px-2.5 text-xs font-semibold text-muted-foreground transition-colors hover:bg-primary/[0.06] hover:text-foreground"
          title={t('shell.resetFilters')}
          aria-label={t('shell.resetFilters')}
        >
          <RotateCcw className="h-3.5 w-3.5" />
          {stacked && t('shell.resetFilters')}
        </button>
      )}
    </div>
  );
}
