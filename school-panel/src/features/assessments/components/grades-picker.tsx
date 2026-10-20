'use client';

import { TILE } from '@/features/dashboard/lib/tile';
import { cn } from '@/lib/utils';

const ALL_GRADES = Array.from({ length: 11 }, (_, i) => i + 1);

/** 1–11-sinflar tanlovi (chiplar). `allowed` — faqat shu sinflarni tanlash mumkin. */
export function GradesPicker({
  value,
  onChange,
  allowed = ALL_GRADES,
  label,
  id,
}: {
  value: number[];
  onChange: (grades: number[]) => void;
  allowed?: readonly number[];
  label?: (grade: number) => string;
  id?: string;
}) {
  const toggle = (g: number) => onChange(value.includes(g) ? value.filter((x) => x !== g) : [...value, g].sort((a, b) => a - b));
  return (
    <div id={id} className="flex flex-wrap gap-1.5" role="group">
      {ALL_GRADES.map((g) => {
        const on = value.includes(g);
        const disabled = !allowed.includes(g);
        return (
          <button
            key={g}
            type="button"
            aria-pressed={on}
            disabled={disabled}
            onClick={() => toggle(g)}
            className={cn(
              TILE,
              'h-9 min-w-9 px-2.5 text-sm font-semibold tabular-nums transition-colors disabled:cursor-not-allowed disabled:opacity-40',
              on ? 'bg-primary/10 text-primary ring-primary/40 dark:bg-primary/15' : 'hover:ring-primary/30',
            )}
          >
            {label ? label(g) : g}
          </button>
        );
      })}
    </div>
  );
}
