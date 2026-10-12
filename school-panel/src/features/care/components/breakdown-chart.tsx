'use client';

import { EyeOff } from 'lucide-react';
import { Bar, BarChart, CartesianGrid, Cell, LabelList, type LabelProps, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { SectionCard } from '@/components/common/section-card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Skeleton } from '@/components/ui/skeleton';
import type { CareAggregate, CareTopic } from '@/data/contracts';
import { CARE_BREAKDOWNS, CARE_TOPICS, type CareBreakdown } from '@/data/schemas/care';
import { useI18n } from '@/i18n';
import { groupScore } from '../lib/insights';
import { groupLabel } from '../lib/labels';

export type ChartTopic = CareTopic | 'AVERAGE';
type Row = { key: string; name: string; score: number | null; placeholder: number | null; respondents: number };

const COLORS = { normal: 'hsl(var(--chart-1))', watch: 'hsl(var(--chart-3))', low: 'hsl(var(--chart-4))' };
const AXIS_WIDTH: Record<CareBreakdown, number> = { SCHOOL: 150, AGE_GROUP: 110, GRADE: 96, CLASS: 48 };
const ROW_HEIGHT = 30;

function barColor(score: number, reference: number | null): string {
  if (reference === null) return COLORS.normal;
  const delta = score - reference;
  if (delta <= -10) return COLORS.low;
  if (delta <= -5) return COLORS.watch;
  return COLORS.normal;
}

function makeLabel(kind: 'score' | 'hidden', text: string) {
  return function ChartLabel({ x, y, width, height, value }: LabelProps) {
    if (value === null || value === undefined) return null;
    const cy = Number(y ?? 0) + Number(height ?? 0) / 2;
    const cx = kind === 'score' ? Number(x ?? 0) + Number(width ?? 0) + 6 : Number(x ?? 0) + 10;
    return (
      <text x={cx} y={cy} dominantBaseline="central" fontSize={11} fontWeight={kind === 'score' ? 600 : 500} fill={kind === 'score' ? 'hsl(var(--foreground))' : 'hsl(var(--muted-foreground))'}>
        {kind === 'score' ? String(value) : text}
      </text>
    );
  };
}

function RowTooltip({ active, payload, hiddenText, respondentsLabel }: { active?: boolean; payload?: Array<{ payload?: Row }>; hiddenText: string; respondentsLabel: string }) {
  const row = payload?.[0]?.payload;
  if (!active || !row) return null;
  return (
    <div className="rounded-lg border bg-popover px-3 py-2 text-xs shadow-soft-lg">
      <p className="font-semibold">{row.name}</p>
      {row.score === null ? (
        <p className="mt-0.5 text-muted-foreground">{hiddenText}</p>
      ) : (
        <p className="mt-0.5 tabular-nums text-muted-foreground">
          <span className="font-semibold text-foreground">{row.score}</span>/100 · {respondentsLabel}: {row.respondents}
        </p>
      )}
    </div>
  );
}

export function BreakdownChart({
  aggregate,
  loading,
  breakdown,
  onBreakdownChange,
  topic,
  onTopicChange,
}: {
  aggregate: CareAggregate | undefined;
  loading?: boolean;
  breakdown: CareBreakdown;
  onBreakdownChange: (value: CareBreakdown) => void;
  topic: ChartTopic;
  onTopicChange: (value: ChartTopic) => void;
}) {
  const { t, tc } = useI18n();
  const topics = CARE_TOPICS.filter((x) => aggregate?.overall[x] !== undefined);
  const reference = aggregate ? groupScore(aggregate.overall, topic) : null;
  const rows: Row[] = (aggregate?.groups ?? []).map((g) => {
    const score = g.hidden ? null : groupScore(g.topicScores, topic);
    return { key: g.key, name: groupLabel(t, breakdown, g), score, placeholder: score === null ? 100 : null, respondents: g.respondents };
  });
  const hiddenCount = aggregate?.groups.filter((g) => g.hidden).length ?? 0;
  const height = Math.max(140, rows.length * ROW_HEIGHT + 48);
  const hiddenText = t('care.overview.hiddenGroup');

  return (
    <SectionCard
      title={t('care.overview.breakdownTitle')}
      description={t('care.overview.breakdownHint')}
      actions={
        <>
          <Select value={breakdown} onValueChange={(v) => onBreakdownChange(v as CareBreakdown)}>
            <SelectTrigger className="h-9 w-36" aria-label={t('care.overview.breakdownTitle')}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {CARE_BREAKDOWNS.map((b) => (
                <SelectItem key={b} value={b}>{t(`care.breakdown.${b}`)}</SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Select value={topic} onValueChange={(v) => onTopicChange(v as ChartTopic)}>
            <SelectTrigger className="h-9 w-48" aria-label={t('care.overview.topic')}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="AVERAGE">{t('care.average')}</SelectItem>
              {topics.map((x) => (
                <SelectItem key={x} value={x}>{t(`enums.careTopic.${x}`)}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </>
      }
    >
      {loading && !aggregate ? (
        <Skeleton className="h-72 w-full rounded-lg" />
      ) : (
        <div style={{ height }} className="animate-fade-in">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={rows} layout="vertical" margin={{ top: 4, right: 36, bottom: 4, left: 4 }} barCategoryGap={6}>
              <defs>
                <pattern id="care-hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
                  <rect width="6" height="6" fill="hsl(var(--muted))" />
                  <line x1="0" y1="0" x2="0" y2="6" stroke="hsl(var(--muted-foreground))" strokeOpacity={0.18} strokeWidth={3} />
                </pattern>
              </defs>
              <CartesianGrid horizontal={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
              <XAxis type="number" domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
              <YAxis type="category" dataKey="name" width={AXIS_WIDTH[breakdown]} tick={{ fontSize: 12, fill: 'hsl(var(--foreground))' }} axisLine={false} tickLine={false} />
              <Tooltip cursor={{ fill: 'hsl(var(--muted) / 0.5)' }} content={<RowTooltip hiddenText={hiddenText} respondentsLabel={t('care.overview.respondents')} />} />
              {reference !== null && (
                <ReferenceLine x={reference} stroke="hsl(var(--muted-foreground))" strokeDasharray="4 4" ifOverflow="extendDomain" />
              )}
              <Bar dataKey="score" stackId="g" radius={[0, 6, 6, 0]} isAnimationActive={false}>
                {rows.map((r) => (
                  <Cell key={r.key} fill={barColor(r.score ?? 0, reference)} />
                ))}
                <LabelList dataKey="score" content={makeLabel('score', '')} />
              </Bar>
              <Bar dataKey="placeholder" stackId="g" fill="url(#care-hatch)" radius={6} isAnimationActive={false}>
                <LabelList dataKey="placeholder" content={makeLabel('hidden', hiddenText)} />
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
      <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-muted-foreground">
        <Legend color={COLORS.normal} label={t('care.overview.legendNormal')} />
        <Legend color={COLORS.watch} label={t('care.overview.legendWatch')} />
        <Legend color={COLORS.low} label={t('care.overview.legendLow')} />
        {reference !== null && <span className="tabular-nums">┆ {t('care.overview.schoolAverage', { value: reference })}</span>}
        <span className="ml-auto flex items-center gap-1.5">
          <EyeOff className="h-3.5 w-3.5" />
          {hiddenCount > 0 ? tc('care.overview.hiddenGroups', hiddenCount) : t('care.overview.noHidden')}
        </span>
      </div>
    </SectionCard>
  );
}

function Legend({ color, label }: { color: string; label: string }) {
  return (
    <span className="flex items-center gap-1.5">
      <span className="h-2.5 w-2.5 rounded-sm" style={{ background: color }} aria-hidden />
      {label}
    </span>
  );
}
