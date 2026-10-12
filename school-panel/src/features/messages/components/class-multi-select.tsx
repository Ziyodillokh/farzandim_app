'use client';

import { Check } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { INNER_TILE, SELECTED_SOFT } from '../styles';

export type ClassChoice = { id: string; name: string; grade: number; size: number };

/** Sinflarni parallel (1-sinf, 2-sinf…) bo'yicha guruhlab tanlash. */
export function ClassMultiSelect({
  classes,
  value,
  onChange,
  loading,
}: {
  classes: ClassChoice[] | undefined;
  value: string[];
  onChange: (next: string[]) => void;
  loading?: boolean;
}) {
  const { t } = useI18n();
  if (loading || !classes) return <Skeleton className="h-32 w-full rounded-xl" />;

  const selected = new Set(value);
  const grades = [...new Set(classes.map((c) => c.grade))].sort((a, b) => a - b);
  const toggle = (ids: string[]) => {
    const allOn = ids.every((id) => selected.has(id));
    onChange(allOn ? value.filter((id) => !ids.includes(id)) : [...new Set([...value, ...ids])]);
  };

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-xs text-muted-foreground">{t('messages.audience.selected', { count: value.length })}</p>
        <div className="flex gap-1">
          <Button type="button" size="sm" variant="ghost" onClick={() => onChange(classes.map((c) => c.id))}>
            {t('messages.audience.selectAll')}
          </Button>
          <Button type="button" size="sm" variant="ghost" onClick={() => onChange([])} disabled={value.length === 0}>
            {t('messages.audience.clear')}
          </Button>
        </div>
      </div>
      <div className="grid gap-2 sm:grid-cols-2">
        {grades.map((grade) => {
          const inGrade = classes.filter((c) => c.grade === grade);
          const ids = inGrade.map((c) => c.id);
          const allOn = ids.every((id) => selected.has(id));
          return (
            <div key={grade} className={cn(INNER_TILE, 'flex items-center gap-2 p-2')}>
              <button
                type="button"
                onClick={() => toggle(ids)}
                className={cn(
                  'w-16 shrink-0 rounded-lg px-2 py-1.5 text-left text-xs font-semibold transition-colors',
                  allOn ? SELECTED_SOFT : 'text-muted-foreground hover:bg-primary/[0.06] hover:text-foreground',
                )}
              >
                {t('messages.audience.gradeGroup', { grade })}
              </button>
              <div className="flex flex-wrap gap-1.5">
                {inGrade.map((c) => {
                  const on = selected.has(c.id);
                  return (
                    <button
                      key={c.id}
                      type="button"
                      aria-pressed={on}
                      onClick={() => toggle([c.id])}
                      className={cn(
                        'inline-flex items-center gap-1 rounded-lg px-2.5 py-1 text-sm font-medium transition-all',
                        on ? SELECTED_SOFT : 'bg-white/70 ring-1 ring-inset ring-border/70 hover:ring-primary/40 dark:bg-white/[0.04]',
                      )}
                    >
                      {on && <Check className="h-3.5 w-3.5" />}
                      {c.name}
                    </button>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
