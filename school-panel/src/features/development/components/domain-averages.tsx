'use client';

import { BarChart3 } from 'lucide-react';
import { useId } from 'react';
import { Bar, BarChart, CartesianGrid, LabelList, type LabelProps, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { SectionCard } from '@/components/common/section-card';
import { Skeleton } from '@/components/ui/skeleton';
import type { DevDomain } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { domainKey } from '../lib/domains';
import { DevTooltip } from './chart-parts';

export type DomainAverageRow = { domain: DevDomain; index: number | null; compare?: number | null };
type Datum = { name: string; index: number | null; compare: number | null; ghost: number | null };

const ROW = 34;
const MAIN = 'hsl(var(--primary))';
const SECOND = 'hsl(var(--info) / 0.55)';

/** `hiddenText` berilsa — faqat yashirin qatorlar uchun, aks holda faqat qiymatli qatorlar uchun. */
function valueLabel(hiddenText?: string) {
  return function Label({ x, y, width, height, value }: LabelProps) {
    const isHidden = value === null || value === undefined;
    if (isHidden !== Boolean(hiddenText)) return null;
    const cy = Number(y ?? 0) + Number(height ?? 0) / 2;
    const cx = isHidden ? Number(x ?? 0) + 8 : Number(x ?? 0) + Number(width ?? 0) + 6;
    return (
      <text x={cx} y={cy} dominantBaseline="central" fontSize={11} fontWeight={isHidden ? 500 : 600} fill={isHidden ? 'hsl(var(--muted-foreground))' : 'hsl(var(--foreground))'}>
        {isHidden ? hiddenText : String(value)}
      </text>
    );
  };
}

/** Sohalar bo'yicha o'rtacha indeks (gorizontal ustunlar), ixtiyoriy taqqoslash bilan. */
export function DomainAverages({
  rows,
  loading,
  title,
  description,
  mainLabel,
  compareLabel,
}: {
  rows: DomainAverageRow[] | undefined;
  loading?: boolean;
  title?: string;
  description?: string;
  mainLabel?: string;
  compareLabel?: string;
}) {
  const { t } = useI18n();
  const id = useId().replace(/:/g, '');
  const hasCompare = Boolean(compareLabel) && (rows ?? []).some((r) => typeof r.compare === 'number');
  // Hech qanday qiymati yo'q soha (o'tkazilmagan) ko'rsatilmaydi; null + taqqoslash bor — yashirin.
  const data: Datum[] = (rows ?? []).filter((r) => r.index !== null || typeof r.compare === 'number' || !compareLabel).map((r) => ({
    name: t(domainKey(r.domain)),
    index: r.index,
    compare: r.compare ?? null,
    ghost: r.index === null ? 100 : null,
  }));
  const main = mainLabel ?? t('development.index');

  return (
    <SectionCard title={title ?? t('development.charts.domainsTitle')} description={description ?? t('development.charts.domainsHint')} icon={<BarChart3 />}>
      {loading && !rows ? (
        <Skeleton className="h-60 w-full rounded-xl" />
      ) : (
        <>
          {hasCompare && (
            <ul className="mb-2 flex flex-wrap gap-4 text-xs text-muted-foreground">
              <li className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-sm" style={{ background: MAIN }} />{main}</li>
              <li className="flex items-center gap-1.5"><span className="h-2.5 w-2.5 rounded-sm" style={{ background: SECOND }} />{compareLabel}</li>
            </ul>
          )}
          <div style={{ height: data.length * (hasCompare ? ROW + 14 : ROW) + 28 }} className="animate-fade-in">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={data} layout="vertical" margin={{ top: 4, right: 36, bottom: 0, left: 0 }} barGap={2}>
                <defs>
                  <pattern id={`${id}-hatch`} width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
                    <line x1="0" y1="0" x2="0" y2="7" stroke="hsl(var(--muted-foreground) / 0.25)" strokeWidth="2" />
                  </pattern>
                </defs>
                <CartesianGrid horizontal={false} stroke="hsl(var(--border))" strokeDasharray="3 3" />
                <XAxis type="number" domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
                <YAxis type="category" dataKey="name" width={124} tick={{ fontSize: 12, fill: 'hsl(var(--foreground))' }} axisLine={false} tickLine={false} />
                <ReferenceLine x={50} stroke="hsl(var(--muted-foreground) / 0.6)" strokeDasharray="4 4" />
                <Tooltip
                  cursor={{ fill: 'hsl(var(--primary) / 0.05)' }}
                  content={({ active, payload }) => {
                    const d = payload?.[0]?.payload as Datum | undefined;
                    if (!active || !d) return null;
                    const rowsOut = [{ key: 'm', label: main, value: d.index ?? t('development.charts.hiddenValue'), swatch: MAIN }];
                    if (hasCompare) rowsOut.push({ key: 'c', label: compareLabel ?? '', value: d.compare ?? '—', swatch: SECOND });
                    return <DevTooltip title={d.name} rows={rowsOut} />;
                  }}
                />
                <Bar dataKey="ghost" stackId="s" fill={`url(#${id}-hatch)`} barSize={14} radius={4} isAnimationActive={false}>
                  <LabelList dataKey="index" content={valueLabel(t('development.charts.hiddenValue'))} />
                </Bar>
                <Bar dataKey="index" stackId="s" fill={MAIN} barSize={14} radius={[0, 4, 4, 0]} isAnimationActive={false}>
                  <LabelList dataKey="index" content={valueLabel()} />
                </Bar>
                {hasCompare && <Bar dataKey="compare" fill={SECOND} barSize={10} radius={[0, 4, 4, 0]} isAnimationActive={false} />}
              </BarChart>
            </ResponsiveContainer>
          </div>
        </>
      )}
    </SectionCard>
  );
}
