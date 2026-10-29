'use client';

import { ArrowDownRight, ArrowUpRight, BookOpenCheck, CalendarClock, Layers3, Scale, Target } from 'lucide-react';

import { Sparkline } from '@/components/charts/sparkline';
import type { Mastery, Scope } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { deltaTone, TONE_TEXT, useMetricFormat } from '@/lib/format';
import { DIFFICULTY_COLORS, DIFFICULTY_LEVELS, hasDifficulty } from './difficulty';
import { CompareBars, Meter, StackBar, SwatchLegend } from './kit/bars';
import { NATIONAL_COLOR } from './kit/colors';
import { CountUpValue, KpiRow, KpiRowSkeleton, KpiTile, SPARK_TONE, UnitValue } from './kit/kpi-tile';
import { gap } from './kit/num';
import { useCompact } from './kit/use-compact';
import { useScopeLabels } from './kit/scope';

const SCOPE_COLOR = 'hsl(214 92% 58%)';

/** Signed qiymat birliksiz: "+1,3" / "−1,5" / "±0,0". */
function useSigned() {
  const fmt = useMetricFormat();
  return (v: number) => `${v > 0 ? '+' : v < 0 ? '−' : '±'}${fmt.num(Math.abs(v), 1)}`;
}

function VsNationalTile({ scope, data }: { scope: Scope; data: Mastery }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const signed = useSigned();
  const { scopeName } = useScopeLabels(scope);
  const diff = gap(data.overall.value, data.national.overall);
  const tone = deltaTone('mastery', diff, 0.25);
  const note = diff === null ? undefined : tone === 'good' ? t('mastery.kpi.above') : tone === 'bad' ? t('mastery.kpi.below') : t('mastery.kpi.level');
  return (
    <KpiTile
      label={t('mastery.kpi.vsNational')}
      icon={<Scale />}
      value={diff === null ? '—' : <UnitValue value={signed(diff)} unit={t('common.units.pp')} />}
      note={note && <span className={TONE_TEXT[tone]}>{note}</span>}
      footer={
        <CompareBars
          className="space-y-1.5 [&_li>div:first-child]:text-[0.72rem]"
          rows={[
            { key: 'scope', label: scopeName, value: data.overall.value, color: SCOPE_COLOR },
            { key: 'national', label: t('common.national'), value: data.national.overall, color: NATIONAL_COLOR },
          ]}
          format={(v) => fmt.value('mastery', v)}
        />
      }
    />
  );
}

function SpreadTile({ heat }: { heat: Mastery['heat'] }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const valid = heat.filter((h) => h.overall !== null).sort((a, b) => (b.overall as number) - (a.overall as number));
  const top = valid[0];
  const bottom = valid.length > 1 ? valid[valid.length - 1] : undefined;
  const spread = top && bottom ? gap(top.overall, bottom.overall) : null;
  const line = (row: (typeof valid)[number], up: boolean) => (
    <li className="flex items-center justify-between gap-2" title={up ? t('mastery.kpi.highest') : t('mastery.kpi.lowest')}>
      <span className="flex min-w-0 items-center gap-1">
        {up ? <ArrowUpRight className="h-3.5 w-3.5 shrink-0 text-emerald-500" /> : <ArrowDownRight className="h-3.5 w-3.5 shrink-0 text-amber-500" />}
        <span className="truncate">{areaName(row.id, { short: true, fallback: row.name })}</span>
      </span>
      <span className="shrink-0 font-semibold tabular-nums">{fmt.value('mastery', row.overall)}</span>
    </li>
  );
  return (
    <KpiTile
      label={t('mastery.kpi.spread')}
      icon={<Scale />}
      value={spread === null ? '—' : <UnitValue value={fmt.num(spread, 1)} unit={t('common.units.pp')} />}
      note={t('mastery.kpi.spreadNote')}
      footer={
        top && bottom ? (
          <ul className="space-y-1 text-[0.72rem]">
            {line(top, true)}
            {line(bottom, false)}
          </ul>
        ) : undefined
      }
    />
  );
}

function DifficultyTile({ difficulty }: { difficulty: Mastery['difficulty'] }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const ok = hasDifficulty(difficulty);
  const parts = DIFFICULTY_LEVELS.map((k) => ({ key: k, label: t(`enums.difficulty.${k}`), value: difficulty[k], color: DIFFICULTY_COLORS[k] }));
  return (
    <KpiTile
      label={t('mastery.kpi.difficulty')}
      icon={<Layers3 />}
      value={ok ? fmt.pct(difficulty.level3) : '—'}
      note={t('mastery.kpi.difficultyNote')}
      footer={
        ok ? (
          <div className="space-y-2">
            <StackBar parts={parts} />
            <SwatchLegend items={parts.map((p) => ({ key: p.key, label: p.label, color: p.color, value: fmt.pct(p.value, 0) }))} className="gap-x-2.5" />
          </div>
        ) : undefined
      }
    />
  );
}

/** O'zlashtirish KPI qatori: umumiy natija, respublika bilan farq (yoki hududlar farqi), muvaffaqiyat, testlar, qiyinlik. */
export function MasteryKpis({ scope, data }: { scope: Scope; data: Mastery | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const compact = useCompact();
  if (!data) return <KpiRowSkeleton />;
  const region = scope.kind === 'REGION';
  return (
    <KpiRow>
      <KpiTile
        label={t('metrics.mastery.title')}
        icon={<BookOpenCheck />}
        value={<CountUpValue metric="mastery" value={data.overall.value} />}
        metric="mastery"
        delta={data.overall.delta}
        note={region ? t('dashboard.vsNationalShort', { value: fmt.value('mastery', data.national.overall) }) : undefined}
        footer={<Sparkline series={data.trend} color={SPARK_TONE[deltaTone('mastery', data.overall.delta)]} />}
      />
      {region ? <VsNationalTile scope={scope} data={data} /> : <SpreadTile heat={data.heat} />}
      <KpiTile
        label={t('metrics.success.title')}
        icon={<Target />}
        value={<CountUpValue metric="success" value={data.success.value} />}
        metric="success"
        delta={data.success.delta}
        note={t('mastery.kpi.successNote')}
        footer={<Meter value={data.success.value} />}
      />
      <KpiTile
        label={t('metrics.tests.title')}
        icon={<CalendarClock />}
        value={<CountUpValue metric="tests" value={data.tests.value} />}
        metric="tests"
        delta={data.tests.delta}
        note={t('mastery.kpi.testsNote')}
        footer={<p className="text-[0.72rem] text-muted-foreground">{t('mastery.kpi.activeLearners', { value: compact(data.tests.n) })}</p>}
      />
      <DifficultyTile difficulty={data.difficulty} />
    </KpiRow>
  );
}
