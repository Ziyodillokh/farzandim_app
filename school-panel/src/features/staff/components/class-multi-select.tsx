'use client';

import { Check } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { useClassOptions } from '@/features/students/hooks';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** Sinflar ko'p tanlovi — parallel bo'yicha ixcham chiplar to'ri. */
export function ClassMultiSelect({ value, onChange, invalid }: { value: string[]; onChange: (next: string[]) => void; invalid?: boolean }) {
  const { t } = useI18n();
  const classes = useClassOptions();
  const selected = new Set(value);

  const toggle = (id: string) => onChange(selected.has(id) ? value.filter((v) => v !== id) : [...value, id]);

  if (classes.isLoading) return <Skeleton className="h-28 w-full rounded-xl" />;

  return (
    <div className={cn('rounded-xl border p-3', invalid && 'border-destructive/60')}>
      <div className="mb-2 flex items-center justify-between text-xs text-muted-foreground">
        <span>{t('staff.form.selected', { count: value.length })}</span>
        {value.length > 0 && (
          <Button type="button" variant="link" size="sm" className="h-auto p-0 text-xs" onClick={() => onChange([])}>
            {t('staff.form.clear')}
          </Button>
        )}
      </div>
      <div className="grid grid-cols-4 gap-1.5 sm:grid-cols-6" role="group" aria-label={t('staff.form.classes')}>
        {(classes.data ?? []).map((c) => {
          const on = selected.has(c.id);
          return (
            <button
              key={c.id}
              type="button"
              aria-pressed={on}
              onClick={() => toggle(c.id)}
              className={cn(
                'flex h-8 items-center justify-center gap-1 rounded-md border text-xs font-semibold tabular-nums transition-colors',
                on ? 'border-primary bg-primary text-primary-foreground shadow-soft' : 'bg-card text-muted-foreground hover:border-primary/40 hover:text-foreground',
              )}
            >
              {on && <Check className="h-3 w-3" />}
              {c.name}
            </button>
          );
        })}
      </div>
    </div>
  );
}
