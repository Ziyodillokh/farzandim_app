'use client';

import { cn } from '@/lib/utils';

/** Segmentli tanlagich (tugmalar guruhi); torda gorizontal aylantiriladi. */
export function Segmented<K extends string>({
  options,
  value,
  onChange,
  label,
  className,
}: {
  options: ReadonlyArray<{ key: K; label: string }>;
  value: K;
  onChange: (key: K) => void;
  label: string;
  className?: string;
}) {
  return (
    <div className={cn('-mx-1 max-w-full overflow-x-auto px-1 py-0.5', className)}>
      <div
        role="group"
        aria-label={label}
        className="inline-flex min-w-max gap-1 rounded-xl bg-primary/[0.06] p-1 ring-1 ring-inset ring-border/60 dark:bg-white/[0.04]"
      >
        {options.map((o) => {
          const active = o.key === value;
          return (
            <button
              key={o.key}
              type="button"
              aria-pressed={active}
              onClick={() => onChange(o.key)}
              className={cn(
                'h-8 rounded-lg px-3.5 text-[0.8rem] font-semibold transition-all',
                active
                  ? 'bg-brand-gradient text-white shadow-[0_6px_18px_-8px_hsl(var(--primary)/0.9)]'
                  : 'text-muted-foreground hover:bg-primary/[0.06] hover:text-foreground dark:hover:bg-white/[0.05]',
              )}
            >
              {o.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}
