'use client';

import { GraduationCap } from 'lucide-react';
import { useId } from 'react';
import { Bar, BarChart, CartesianGrid, LabelList, type LabelProps, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { AbilityBand, SchoolDevOverview } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { ABILITY_BANDS, BAND_FILL, bandShortKey } from '../lib/domains';
import { DevTooltip } from './chart-parts';

type Grade = SchoolDevOverview['cognitiveByGrade'][number];
/** `label` — o'qdagi qisqa (raqam), `title` — tooltipdagi to'liq ("7-sinf"). */
type BandDatum = { label: string; title: string; n: number } & Record<AbilityBand, number> & { counts: Record<AbilityBand, number> };
type MeanDatum = { label: string; title: string; n: number; mean: number | null; ghost: number | null };

const MEAN_MIN = 70;
const MEAN_MAX = 130;

function share(count: number, total: number): number {
  return total > 0 ? Math.round((count / total) * 1000) / 10 : 0;
}

/** Psixolog: har parallelda darajalar ulushi (%); ketma-ket osmon → ko'k. */
function BandsChart({ grades }: { grades: Grade[] }) {
  const { t } = useI18n();
  const data: BandDatum[] = grades.flatMap((g) => {
    if (!g.bands) return [];
    const total = ABILITY_BANDS.reduce((s, b) => s + (g.bands?.[b] ?? 0), 0);
    const pct = Object.fromEntries(ABILITY_BANDS.map((b) => [b, share(g.bands?.[b] ?? 0, total)])) as Record<AbilityBand, number>;
    return [{ label: String(g.grade), title: t('development.charts.gradeLabel', { grade: g.grade }), n: g.n, ...pct, counts: g.bands }];
  });
  return (
    <>
      <div className="h-64 animate-fade-in">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data} margin={{ top: 8, right: 4, bottom: 0, left: -18 }}>
            <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
            <XAxis dataKey="label" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} interval={0} />
            <YAxis domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} unit="%" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
            <Tooltip
              cursor={{ fill: 'hsl(var(--primary) / 0.05)' }}
              content={({ active, payload }) => {
                const d = payload?.[0]?.payload as BandDatum | undefined;
                if (!active || !d) return null;
                const rows = [...ABILITY_BANDS].reverse().map((b) => ({ key: b, label: t(bandShortKey(b)), value: `${d.counts[b]} (${d[b]}%)`, swatch: BAND_FILL[b] }));
                return <DevTooltip title={`${d.title} · n=${d.n}`} rows={rows} />;
              }}
            />
            {ABILITY_BANDS.map((b, i) => (
              <Bar key={b} dataKey={b} stackId="bands" fill={BAND_FILL[b]} stroke="hsl(var(--card))" strokeWidth={2} maxBarSize={36} radius={i === ABILITY_BANDS.length - 1 ? [4, 4, 0, 0] : 0} isAnimationActive={false} />
            ))}
          </BarChart>
        </ResponsiveContainer>
      </div>
      <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-1.5 text-xs text-muted-foreground">
        {ABILITY_BANDS.map((b) => (
          <li key={b} className="flex items-center gap-1.5">
            <span className="h-2.5 w-2.5 rounded-sm" style={{ background: BAND_FILL[b] }} />
            {t(bandShortKey(b))}
          </li>
        ))}
      </ul>
    </>
  );
}

/** Direktor: parallel o'rtacha standart bali; yashirin parallel — shtrixli ustun. */
function MeansChart({ grades }: { grades: Grade[] }) {
  const { t } = useI18n();
  const id = useId().replace(/:/g, '');
  const data: MeanDatum[] = grades.map((g) => ({
    label: String(g.grade),
    title: t('development.charts.gradeLabel', { grade: g.grade }),
    n: g.n,
    mean: g.hidden ? null : g.meanStandard,
    ghost: g.hidden ? MEAN_MAX : null,
  }));
  const label = ({ x, y, width, value }: LabelProps) =>
    value === null || value === undefined ? null : (
      <text x={Number(x ?? 0) + Number(width ?? 0) / 2} y={Number(y ?? 0) - 6} textAnchor="middle" fontSize={11} fontWeight={600} fill="hsl(var(--foreground))">
        {String(value)}
      </text>
    );
  return (
    <div className="h-64 animate-fade-in">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 18, right: 4, bottom: 0, left: -18 }}>
          <defs>
            <pattern id={`${id}-hatch`} width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
              <line x1="0" y1="0" x2="0" y2="7" stroke="hsl(var(--muted-foreground) / 0.25)" strokeWidth="2" />
            </pattern>
          </defs>
          <CartesianGrid vertical={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
          <XAxis dataKey="label" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} interval={0} />
          <YAxis domain={[MEAN_MIN, MEAN_MAX]} ticks={[70, 85, 100, 115, 130]} allowDataOverflow tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
          <ReferenceLine y={100} stroke="hsl(var(--muted-foreground) / 0.6)" strokeDasharray="4 4" />
          <Tooltip
            cursor={{ fill: 'hsl(var(--primary) / 0.05)' }}
            content={({ active, payload }) => {
              const d = payload?.[0]?.payload as MeanDatum | undefined;
              if (!active || !d) return null;
              return d.mean === null ? (
                <DevTooltip title={d.title} rows={[{ key: 'h', label: t('development.charts.mean'), value: t('development.charts.heatHidden') }]} />
              ) : (
                <DevTooltip title={d.title} rows={[{ key: 'm', label: t('development.charts.mean'), value: d.mean }, { key: 'n', label: t('development.charts.count'), value: d.n }]} />
              );
            }}
          />
          <Bar dataKey="ghost" stackId="m" fill={`url(#${id}-hatch)`} maxBarSize={36} radius={[4, 4, 0, 0]} isAnimationActive={false} />
          <Bar dataKey="mean" stackId="m" fill="hsl(var(--primary))" maxBarSize={36} radius={[4, 4, 0, 0]} isAnimationActive={false}>
            <LabelList dataKey="mean" content={label} />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

export function GradeDistribution({ overview, loading }: { overview: SchoolDevOverview | undefined; loading?: boolean }) {
  const { t } = useI18n();
  const grades = overview?.cognitiveByGrade ?? [];
  const bands = grades.some((g) => g.bands !== null);
  return (
    <SectionCard
      title={t('development.charts.gradesTitle')}
      description={bands ? t('development.charts.gradesHintBands') : t('development.charts.gradesHintMean')}
      icon={<GraduationCap />}
    >
      {loading && !overview ? (
        <Skeleton className="h-64 w-full rounded-xl" />
      ) : grades.length === 0 ? (
        <EmptyState title={t('development.empty.noTerm')} className="py-10" />
      ) : bands ? (
        <BandsChart grades={grades} />
      ) : (
        <MeansChart grades={grades} />
      )}
    </SectionCard>
  );
}
