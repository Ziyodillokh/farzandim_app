'use client';

import { BarChart3 } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Bar, BarChart, CartesianGrid, Cell, LabelList, type LabelProps, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { PsychScale, ScoreBand } from '@/data/contracts';
import type { BandBucket } from '@/data/mock/services/assessments';
import { ChartTooltip } from '@/features/dashboard/components/chart-tooltip';
import { useI18n } from '@/i18n';
import { bandColor, bandLabel } from '../lib/labels';

type Row = { key: string; name: string; full: string; count: number };

/** Tor konteynerda (telefon) — gorizontal ustunlar, uzun yorliqlar ustma-ust tushmasin. */
const NARROW_PX = 560;
const ROW_PX = 40;

function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el || typeof ResizeObserver === 'undefined') return;
    const observer = new ResizeObserver(([entry]) => setWidth(entry?.contentRect.width ?? 0));
    observer.observe(el);
    return () => observer.disconnect();
  }, []);
  return [ref, width] as const;
}

const LABEL_STYLE = { fontSize: 12, fontWeight: 600, fill: 'hsl(var(--foreground))' } as const;

type Box = { x: number; y: number; w: number; h: number };

/** Yorliq joylashuvi: `x/y/width/height` yoki `viewBox` — hammasi chekli son bo'lsa. */
function labelBox(p: LabelProps): Box | null {
  const vb = (p.viewBox ?? {}) as Partial<Record<'x' | 'y' | 'width' | 'height', number>>;
  const box = { x: Number(p.x ?? vb.x), y: Number(p.y ?? vb.y), w: Number(p.width ?? vb.width ?? 0), h: Number(p.height ?? vb.height ?? 0) };
  return Object.values(box).every(Number.isFinite) ? box : null;
}

/** Ustun ustidagi son (vertikal ustunlar). */
function TopLabel(p: LabelProps) {
  const b = labelBox(p);
  if (!b || p.value === undefined || p.value === null) return null;
  return (
    <text x={b.x + b.w / 2} y={b.y - 6} textAnchor="middle" {...LABEL_STYLE}>
      {String(p.value)}
    </text>
  );
}

/** Ustun yonidagi son (gorizontal ustunlar). */
function SideLabel(p: LabelProps) {
  const b = labelBox(p);
  if (!b || p.value === undefined || p.value === null) return null;
  return (
    <text x={b.x + b.w + 6} y={b.y + b.h / 2} dominantBaseline="central" {...LABEL_STYLE}>
      {String(p.value)}
    </text>
  );
}

/** Darajalar taqsimoti (ko'k soyalar). Kasbiy qiziqishda — yetakchi yo'nalish. */
export function BandChart({
  distribution,
  loading,
  career,
  scales,
}: {
  distribution: BandBucket[] | undefined;
  loading?: boolean;
  career: boolean;
  scales: readonly PsychScale[];
}) {
  const { t, locale } = useI18n();
  const rows: Row[] = (distribution ?? []).map((b) => {
    const scale = scales.find((s) => s.key === b.band);
    const name = career ? (scale?.label[locale] ?? b.band) : bandLabel(t, b.band as ScoreBand, true);
    return { key: b.band, name, full: career ? name : bandLabel(t, b.band as ScoreBand), count: b.count };
  });
  const total = rows.reduce((s, r) => s + r.count, 0);
  const [ref, width] = useWidth<HTMLDivElement>();
  const narrow = width > 0 && width < NARROW_PX;
  const axisTick = { fontSize: 11, fill: 'hsl(var(--muted-foreground))' };

  return (
    <SectionCard
      icon={<BarChart3 />}
      title={career ? t('assessments.results.careerDistribution') : t('assessments.results.distribution')}
      description={t('assessments.results.distributionHint')}
      className="h-full"
    >
      <div ref={ref}>
      {loading && !distribution ? (
        <Skeleton className="h-64 w-full rounded-xl" />
      ) : total === 0 ? (
        <p className="flex h-64 items-center justify-center text-sm text-muted-foreground">{t('assessments.results.empty')}</p>
      ) : (
        <div
          className="animate-fade-in"
          style={{ height: narrow ? rows.length * ROW_PX + 24 : 256 }}
          role="img"
          aria-label={rows.map((r) => `${r.full}: ${r.count}`).join('; ')}
        >
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              key={narrow ? 'narrow' : 'wide'}
              data={rows}
              layout={narrow ? 'vertical' : 'horizontal'}
              margin={narrow ? { top: 4, right: 36, bottom: 4, left: 4 } : { top: 22, right: 8, bottom: 4, left: -18 }}
              barCategoryGap="22%"
            >
              <CartesianGrid vertical={narrow} horizontal={!narrow} stroke="hsl(var(--border))" strokeDasharray="3 3" />
              {narrow && <XAxis type="number" hide allowDecimals={false} />}
              {narrow && <YAxis type="category" dataKey="name" width={122} tick={{ ...axisTick, fill: 'hsl(var(--foreground))' }} axisLine={false} tickLine={false} />}
              {!narrow && <XAxis dataKey="name" tick={axisTick} axisLine={false} tickLine={false} interval={0} />}
              {!narrow && <YAxis allowDecimals={false} tick={axisTick} axisLine={false} tickLine={false} />}
              <Tooltip
                cursor={{ fill: 'hsl(var(--primary) / 0.06)' }}
                content={({ active, payload }) => {
                  const row = payload?.[0]?.payload as Row | undefined;
                  return (
                    <ChartTooltip
                      active={active}
                      label={row?.full}
                      payload={row ? [{ name: t('assessments.results.count'), value: row.count, color: 'hsl(var(--primary))' }] : []}
                    />
                  );
                }}
              />
              <Bar dataKey="count" radius={narrow ? [3, 8, 8, 3] : [8, 8, 3, 3]} isAnimationActive={false} maxBarSize={64}>
                {rows.map((r, i) => (
                  <Cell key={r.key} fill={bandColor(i, rows.length)} />
                ))}
                <LabelList dataKey="count" content={narrow ? SideLabel : TopLabel} />
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
      </div>
    </SectionCard>
  );
}
