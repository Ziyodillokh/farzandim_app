'use client';

import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { ISO_WEEKDAYS } from '../lib/settings';

/**
 * Hafta kunlari tugmalari (ko'p tanlov). Har tugma — `aria-pressed`; to'liq kun nomi `aria-label`da,
 * ekranda qisqa nom. Guruh nomi tashqi yorliqdan (`labelledBy`) olinadi.
 */
export function WorkDaysPicker({
  value,
  onChange,
  disabled,
  invalid,
  labelledBy,
  id,
}: {
  value: readonly number[];
  onChange: (next: number[]) => void;
  disabled?: boolean;
  invalid?: boolean;
  labelledBy: string;
  id?: string;
}) {
  const { t } = useI18n();
  const toggle = (day: number) => onChange(value.includes(day) ? value.filter((d) => d !== day) : [...value, day].sort((a, b) => a - b));

  return (
    <div id={id} role="group" aria-labelledby={labelledBy} data-invalid={invalid || undefined} tabIndex={invalid ? -1 : undefined} className="flex flex-wrap gap-1.5 focus-visible:outline-none">
      {ISO_WEEKDAYS.map((day) => {
        const on = value.includes(day);
        return (
          <button
            key={day}
            type="button"
            aria-pressed={on}
            aria-label={t(`enums.weekday.${day}`)}
            disabled={disabled}
            onClick={() => toggle(day)}
            className={cn(
              'h-10 min-w-11 rounded-xl px-3 text-sm font-semibold ring-1 ring-inset transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-60',
              on ? 'bg-primary/15 text-primary ring-primary/35' : 'bg-white/50 text-muted-foreground ring-border/60 hover:text-foreground dark:bg-white/[0.03]',
              invalid && !on && 'ring-destructive/50',
            )}
          >
            <span aria-hidden>{t(`enums.weekdayShort.${day}`)}</span>
          </button>
        );
      })}
    </div>
  );
}
