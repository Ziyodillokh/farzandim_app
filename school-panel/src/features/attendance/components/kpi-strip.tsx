import type { ReactNode } from 'react';

import type { Tone } from '@/components/common/stat-card';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { cn } from '@/lib/utils';

const ICON_TONES: Record<Tone, string> = {
  primary: 'bg-primary/10 text-primary ring-primary/20',
  success: 'bg-success/10 text-success ring-success/20',
  warning: 'bg-warning/15 text-warning ring-warning/25',
  destructive: 'bg-destructive/10 text-destructive ring-destructive/20',
  info: 'bg-info/10 text-info ring-info/20',
  muted: 'bg-muted text-muted-foreground ring-border',
};

const BAR_TONES: Record<Tone, string> = {
  primary: 'bg-primary',
  success: 'bg-success',
  warning: 'bg-warning',
  destructive: 'bg-destructive',
  info: 'bg-info',
  muted: 'bg-muted-foreground/45',
};

export type KpiItem = {
  key: string;
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  tone: Tone;
  icon: ReactNode;
  /** 0..100 — plitka ostidagi ingichka ulush chizig'i. */
  share?: number;
  /** Chiziq o'rniga maxsus pastki qism (masalan, holatlar chizig'i). */
  footer?: ReactNode;
  /** Asosiy ko'rsatkich — yumshoq ko'k fon bilan ajratiladi. */
  emphasis?: boolean;
  title?: string;
};

/**
 * Ixcham KPI qatori: bitta shisha karta ichida ichki plitkalar
 * (alohida baland kartalar o'rniga — sahifa tepasi yengil va tartibli).
 */
export function KpiStrip({ items, loading, className }: { items: KpiItem[]; loading?: boolean; className?: string }) {
  return (
    <Card className="mb-6 p-2">
      <div className={cn('grid grid-cols-2 gap-2 sm:grid-cols-3', className)}>
        {items.map((item) => (
          <div
            key={item.key}
            title={item.title}
            className={cn(
              'flex min-w-0 flex-col rounded-xl p-3.5 ring-1 ring-inset',
              item.emphasis
                ? 'bg-gradient-to-br from-primary/[0.12] via-primary/[0.05] to-transparent ring-primary/20'
                : 'bg-white/50 ring-border/60 dark:bg-white/[0.03]',
            )}
          >
            <div className="flex items-center gap-2">
              <span className={cn('flex h-7 w-7 shrink-0 items-center justify-center rounded-lg ring-1 ring-inset [&_svg]:size-3.5', ICON_TONES[item.tone])}>
                {item.icon}
              </span>
              <span className="truncate text-xs font-medium text-muted-foreground">{item.label}</span>
            </div>
            {loading ? (
              <Skeleton className="mt-3 h-7 w-20" />
            ) : (
              <p className="mt-2.5 font-display text-[1.6rem] font-semibold leading-none tracking-[-0.02em] tabular-nums">{item.value}</p>
            )}
            <div className="mt-auto pt-3">
              {item.footer ??
                (item.share !== undefined && (
                  <div className="h-1 overflow-hidden rounded-full bg-primary/[0.08] dark:bg-white/[0.06]">
                    <div className={cn('h-full rounded-full transition-[width] duration-700', BAR_TONES[item.tone])} style={{ width: `${Math.min(100, item.share)}%` }} />
                  </div>
                ))}
              {item.hint && !loading && <p className="mt-1.5 truncate text-2xs text-muted-foreground tabular-nums">{item.hint}</p>}
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}
