import type { ReactNode } from 'react';

import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { cn } from '@/lib/utils';

export type Tone = 'primary' | 'success' | 'warning' | 'destructive' | 'info' | 'muted';

const TONES: Record<Tone, string> = {
  primary: 'bg-primary/10 text-primary',
  success: 'bg-success/12 text-success',
  warning: 'bg-warning/15 text-warning',
  destructive: 'bg-destructive/10 text-destructive',
  info: 'bg-info/12 text-info',
  muted: 'bg-muted text-muted-foreground',
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
    <Card className={cn('card-glow p-5', className)}>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-sm font-medium text-muted-foreground">{label}</p>
          {loading ? (
            <Skeleton className="mt-2 h-8 w-24" />
          ) : (
            <p className="mt-1.5 font-display text-[1.65rem] font-semibold leading-none tracking-tight tabular-nums">{value}</p>
          )}
          {hint && !loading && <div className="mt-2 text-xs text-muted-foreground">{hint}</div>}
        </div>
        <div className={cn('flex h-11 w-11 shrink-0 items-center justify-center rounded-xl [&_svg]:size-5', TONES[tone])}>{icon}</div>
      </div>
      {footer && <div className="mt-4">{footer}</div>}
    </Card>
  );
}

export function toneClass(tone: Tone): string {
  return TONES[tone];
}
