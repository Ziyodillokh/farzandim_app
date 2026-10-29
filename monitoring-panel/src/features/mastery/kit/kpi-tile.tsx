'use client';

import Link from 'next/link';
import type { ReactNode } from 'react';

import { DeltaChip } from '@/components/charts/delta-chip';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { MetricKey } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { type Tone, useMetricFormat } from '@/lib/format';
import { useCountUp } from '@/lib/use-count-up';
import { cn } from '@/lib/utils';

const KPI_TILES = 5;

/** Sparkline rangi (dashboard KPI kartalari bilan bir xil). */
export const SPARK_TONE: Record<Tone, string> = {
  good: 'hsl(158 64% 45%)',
  bad: 'hsl(36 92% 56%)',
  neutral: 'hsl(var(--primary))',
};

/**
 * O'quv sahifalarining KPI qatori: 5 karta. Mobil — 2 ustun, planshet — 3 ustun;
 * oxirgi karta bo'sh joyni to'ldirish uchun keng.
 */
export function KpiRow({ children }: { children: ReactNode }) {
  return (
    <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5 [&>*:last-child]:col-span-2 xl:[&>*:last-child]:col-span-1">
      {children}
    </div>
  );
}

export function KpiRowSkeleton() {
  return (
    <KpiRow>
      {Array.from({ length: KPI_TILES }, (_, i) => (
        <Card key={i} className="h-full p-4">
          <Skeleton className="h-4 w-24" />
          <Skeleton className="mt-3 h-7 w-20" />
          <Skeleton className="mt-3 h-5 w-16" />
          <Skeleton className="mt-4 h-9 w-full" />
        </Card>
      ))}
    </KpiRow>
  );
}

/** Ko'rsatkich qiymati — 0 dan silliq o'sadi (dashboard KPI kabi). */
export function CountUpValue({ metric, value }: { metric: MetricKey; value: number | null }) {
  const fmt = useMetricFormat();
  const animated = useCountUp(value);
  return <>{fmt.value(metric, animated)}</>;
}

/** Katta raqam + kichik birlik ("−1,5 p.p."). */
export function UnitValue({ value, unit }: { value: string; unit: string }) {
  return (
    <>
      {value}
      <span className="ml-1 font-sans text-[0.95rem] font-semibold tracking-normal text-muted-foreground">{unit}</span>
    </>
  );
}

export type KpiTileProps = {
  label: string;
  value: ReactNode;
  icon?: ReactNode;
  /** Berilsa — o'tgan yilga nisbatan o'zgarish belgisi (rang ko'rsatkich yo'nalishidan). */
  metric?: MetricKey;
  delta?: number | null;
  note?: ReactNode;
  footer?: ReactNode;
  href?: string;
  /** Matnli qiymatlar (fan, soha nomi) uchun kichikroq shrift. */
  textValue?: boolean;
  className?: string;
};

/** KPI kartasi: nom, katta qiymat, o'zgarish, izoh va pastki qism (sparkline, ulush chizig'i). */
export function KpiTile({ label, value, icon, metric, delta, note, footer, href, textValue = false, className }: KpiTileProps) {
  const { t } = useI18n();
  const chip = metric !== undefined && delta !== null && delta !== undefined ? <DeltaChip metric={metric} delta={delta} title={t('common.vsLastYear')} /> : null;
  const body = (
    <Card className={cn('card-glow relative flex h-full flex-col overflow-hidden p-4', className)}>
      <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_100%_0%,hsl(var(--primary)/0.12),transparent_60%)]" />
      <div className="relative flex items-start justify-between gap-2">
        <p className="text-[0.8rem] font-medium text-muted-foreground">{label}</p>
        {icon && (
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/20 [&_svg]:size-4">{icon}</span>
        )}
      </div>
      <div
        className={cn(
          'relative mt-1 font-semibold',
          // Matnli qiymat — oddiy shrift: uzun so'zlar ("Исследовательский") bo'linmasin.
          textValue ? 'text-[1.1rem] leading-snug tracking-[-0.01em] [hyphens:auto] [overflow-wrap:break-word]' : 'font-display text-[1.7rem] leading-none tracking-[-0.02em] tabular-nums',
        )}
      >
        {value}
      </div>
      {(chip || note) && (
        <div className="relative mt-2 flex flex-wrap items-center gap-1.5">
          {chip}
          {note && <span className="text-[0.72rem] leading-snug text-muted-foreground">{note}</span>}
        </div>
      )}
      {footer && <div className="relative mt-auto pt-3">{footer}</div>}
    </Card>
  );
  if (!href) return body;
  return (
    <Link href={href} className="block h-full rounded-2xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" aria-label={label}>
      {body}
    </Link>
  );
}
