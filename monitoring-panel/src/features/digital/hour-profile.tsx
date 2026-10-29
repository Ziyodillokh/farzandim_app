'use client';

import { Bar, BarChart, CartesianGrid, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { ChartTooltip } from '@/components/charts/chart-tooltip';
import { extremeAllBy } from '@/features/wellbeing/kit/analysis';
import { ChartBlock, ChartLegend } from '@/features/wellbeing/kit/chart-block';
import { trimZeroDecimals } from '@/features/wellbeing/kit/mini-columns';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';

type Band = 'night' | 'lesson' | 'other';

/** Kun bo'laklari: tun 22:00–06:00, dars vaqti 08:00–13:00 (formulalar bilan bir xil). */
const NIGHT_FROM = 22;
const NIGHT_TO = 6;
const LESSON_FROM = 8;
const LESSON_TO = 13;
/** X o'qida har 3 soatda belgi. */
const TICK_EVERY = 3;

const BAND_COLORS: Record<Band, string> = {
  night: 'hsl(40 92% 54%)',
  lesson: 'hsl(var(--chart-5))',
  other: 'hsl(var(--chart-1))',
};

export function bandOf(hour: number): Band {
  if (hour >= NIGHT_FROM || hour < NIGHT_TO) return 'night';
  if (hour >= LESSON_FROM && hour < LESSON_TO) return 'lesson';
  return 'other';
}

const hh = (h: number) => `${String(h % 24).padStart(2, '0')}:00`;

/** Eng faol soatlarning birinchi uzluksiz oralig'i (masalan, 19–21). */
function firstRun(hours: readonly number[]): { from: number; to: number } | null {
  const sorted = [...hours].sort((a, b) => a - b);
  const from = sorted[0];
  if (from === undefined) return null;
  let to = from;
  for (const h of sorted.slice(1)) {
    if (h !== to + 1) break;
    to = h;
  }
  return { from, to };
}

/**
 * 24 soatlik foydalanish profili: tun — amber, dars vaqti — moviy, qolgani — ko'k.
 * Legenda har bo'lakning jami ulushi bilan (rang yagona kanal emas).
 */
export function HourProfile({ hourly }: { hourly: readonly number[] }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const data = hourly.map((value, hour) => ({ key: String(hour), label: String(hour).padStart(2, '0'), value, band: bandOf(hour), hour }));
  const sum = (band: Band) => data.filter((d) => d.band === band).reduce((s, d) => s + d.value, 0);
  const peak = extremeAllBy(data, (d) => d.value, 'max');
  const run = peak && peak.value > 0 ? firstRun(peak.items.map((d) => d.hour)) : null;
  const peakLabel = run ? `${hh(run.from)}–${hh(run.to + 1)}` : null;
  const tooltipLabel = new Map(data.map((d) => [d.label, `${hh(d.hour)}–${hh(d.hour + 1)}`]));

  return (
    <ChartBlock
      title={t('digital.usage.hourly')}
      caption={peakLabel && t('digital.usage.peak', { hours: peakLabel })}
      aside={<span className="text-[0.7rem] text-muted-foreground">{t('digital.usage.hourlyNote')}</span>}
    >
      <ChartLegend
        className="mb-2"
        items={[
          { key: 'night', label: t('digital.usage.night'), color: BAND_COLORS.night, value: fmt.pct(sum('night')) },
          { key: 'lesson', label: t('digital.usage.lesson'), color: BAND_COLORS.lesson, value: fmt.pct(sum('lesson')) },
          { key: 'other', label: t('digital.usage.other'), color: BAND_COLORS.other, value: fmt.pct(sum('other')) },
        ]}
      />
      <div className="h-[200px] w-full">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data} margin={{ top: 8, right: 4, bottom: 0, left: -10 }} barCategoryGap={2}>
            <CartesianGrid stroke="hsl(var(--border))" strokeDasharray="3 4" vertical={false} />
            <XAxis
              dataKey="label"
              tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
              axisLine={false}
              tickLine={false}
              interval={TICK_EVERY - 1}
            />
            <YAxis
              tickFormatter={(v: number) => trimZeroDecimals(fmt.pct(v, 0))}
              tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
              axisLine={false}
              tickLine={false}
              width={40}
              allowDecimals={false}
            />
            <Tooltip
              cursor={{ fill: 'hsl(var(--primary) / 0.06)' }}
              content={<ChartTooltip formatLabel={(l) => tooltipLabel.get(l) ?? l} formatValue={(v) => fmt.pct(v)} />}
            />
            <Bar dataKey="value" name={t('common.share')} radius={[3, 3, 0, 0]} maxBarSize={22} isAnimationActive={false}>
              {data.map((d) => (
                <Cell key={d.key} fill={BAND_COLORS[d.band]} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </ChartBlock>
  );
}
