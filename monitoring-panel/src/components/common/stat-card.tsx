import type { ReactNode } from 'react';

import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { cn } from '@/lib/utils';

export type Tone = 'primary' | 'success' | 'warning' | 'destructive' | 'info' | 'muted';

const TONES: Record<Tone, string> = {
  primary: 'bg-primary/10 text-primary ring-primary/20',
  success: 'bg-success/10 text-success ring-success/20',
  warning: 'bg-warning/15 text-warning ring-warning/25',
  destructive: 'bg-destructive/10 text-destructive ring-destructive/20',
  info: 'bg-info/10 text-info ring-info/20',
  muted: 'bg-muted text-muted-foreground ring-border',
};

/** Kartaning yuqori o'ng burchagidagi yumshoq rangli nur (blursiz — radial gradient). */
const GLOWS: Record<Tone, string> = {
  primary: 'bg-[radial-gradient(circle_at_100%_0%,hsl(var(--primary)/0.14),transparent_62%)]',
  success: 'bg-[radial-gradient(circle_at_100%_0%,hsl(var(--success)/0.14),transparent_62%)]',
  warning: 'bg-[radial-gradient(circle_at_100%_0%,hsl(var(--warning)/0.16),transparent_62%)]',
  destructive: 'bg-[radial-gradient(circle_at_100%_0%,hsl(var(--destructive)/0.13),transparent_62%)]',
  info: 'bg-[radial-gradient(circle_at_100%_0%,hsl(var(--info)/0.14),transparent_62%)]',
  muted: 'bg-[radial-gradient(circle_at_100%_0%,hsl(var(--muted-foreground)/0.08),transparent_62%)]',
};

export function StatCard({
  icon,
  label,
  value,
  hint,
  tone = 'primary',
  loading,
  footer,
  className,
}: {
  icon: ReactNode;
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  tone?: Tone;
  loading?: boolean;
  footer?: ReactNode;
  className?: string;
}) {
  return (
    <Card className={cn('card-glow relative overflow-hidden p-5', className)}>
      <div aria-hidden className={cn('pointer-events-none absolute inset-0', GLOWS[tone])} />
      <div className="relative flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-sm font-medium text-muted-foreground">{label}</p>
          {loading ? (
            <Skeleton className="mt-2 h-8 w-24" />
          ) : (
            <p className="mt-2 font-display text-[1.75rem] font-semibold leading-none tracking-[-0.02em] tabular-nums">{value}</p>
          )}
          {hint && !loading && <div className="mt-2 text-xs text-muted-foreground">{hint}</div>}
        </div>
        <div className={cn('flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl ring-1 ring-inset [&_svg]:size-5', TONES[tone])}>{icon}</div>
      </div>
      {footer && <div className="relative mt-4">{footer}</div>}
    </Card>
  );
}

export function toneClass(tone: Tone): string {
  return TONES[tone];
}
