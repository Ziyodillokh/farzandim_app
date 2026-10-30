'use client';

import { ArrowUpRight } from 'lucide-react';
import Link from 'next/link';

import { useCan } from '@/auth/use-session';
import { DeltaChip } from '@/components/charts/delta-chip';
import type { Scope } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { useMetricFormat } from '@/lib/format';
import { oneIn } from './kit/analysis';
import { BlockTitle } from './kit/chart-block';
import { type Hotspot, NOTABLE_EXCESS, NOTABLE_MIN_DIFF, type ProblemRank } from './problem-analysis';
import { type ProblemKey, problemLabelKey } from './problem-keys';

/** "Har N boladan 1 tasi" iborasi faqat bolalar ulushi bo'lgan signallar uchun. */
const CHILD_SHARE: ReadonlySet<ProblemKey> = new Set(['bullying', 'anxiety', 'support', 'sleep', 'safetyGap', 'chronic']);

/** Signallar keng tarqalganligi: bosh xulosa + barcha signallar ustunlari. */
export function WidespreadPanel({ ranks }: { ranks: readonly ProblemRank[] }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const lead = ranks.find((r) => CHILD_SHARE.has(r.metric as ProblemKey) && r.value !== null);
  const leadN = lead ? oneIn(lead.value) : null;
  const max = Math.max(1, ...ranks.map((r) => r.value ?? 0));
  return (
    <div className="min-w-0">
      <BlockTitle className="mb-3">{t('wellbeing.problems.widespread')}</BlockTitle>
      {lead && (
        <div className="mb-4 rounded-xl bg-primary/[0.06] px-4 py-3 ring-1 ring-inset ring-primary/15 dark:bg-white/[0.03]">
          <p className="text-[0.95rem] leading-snug">
            <b className="font-semibold">{t(problemLabelKey(lead.metric))}</b>
            {leadN !== null && <> — {t('wellbeing.problems.leadOneIn', { n: leadN })}</>}
          </p>
          <div className="mt-1.5 flex flex-wrap items-center gap-2">
            <span className="font-display text-[1.35rem] font-semibold leading-none tabular-nums">{fmt.value(lead.metric, lead.value)}</span>
            <DeltaChip metric={lead.metric} delta={lead.delta} title={t('common.vsLastYear')} />
          </div>
        </div>
      )}
      <ul className="space-y-3">
        {ranks.map((r) => (
          <li key={r.metric}>
            <div className="mb-1 flex items-baseline justify-between gap-3 text-[0.8rem]">
              <span className="min-w-0 truncate font-medium">{t(problemLabelKey(r.metric))}</span>
              <b className="shrink-0 font-semibold tabular-nums">{fmt.value(r.metric, r.value)}</b>
            </div>
            <div className="h-2 rounded-full bg-muted/70">
              <span className="block h-full rounded-full bg-brand-gradient transition-[width] duration-700" style={{ width: `${Math.max(3, ((r.value ?? 0) / max) * 100)}%` }} />
            </div>
            {r.peak && (
              <p className="mt-1 text-[0.7rem] text-muted-foreground">
                {t('wellbeing.problems.peak', { area: areaName(r.peak.id, { short: true, fallback: r.peak.name }), value: fmt.value(r.metric, r.peak.value) })}
              </p>
            )}
          </li>
        ))}
      </ul>
      <p className="mt-3 text-[0.7rem] text-muted-foreground">{t('wellbeing.problems.shareNote')}</p>
    </div>
  );
}

/** Bitta hudud (tuman): o'rni, nomi, sezilarli yuqori signallar soni va chiplar (qiymat, o'rtachadan farq — p.p.). */
function HotspotCard({ hotspot, rank, total, linkable }: { hotspot: Hotspot; rank: number; total: number; linkable: boolean }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const name = areaName(hotspot.id, { short: true, fallback: hotspot.name });
  return (
    <li className="rounded-xl bg-primary/[0.04] p-3 ring-1 ring-inset ring-border/50 dark:bg-white/[0.025]">
      <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
        <span className="flex min-w-0 items-center gap-2">
          <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-lg bg-amber-500/15 text-[0.72rem] font-bold tabular-nums text-amber-700 dark:text-amber-300">{rank}</span>
          {linkable ? (
            <Link href={`/regions/view?id=${hotspot.id}`} className="group inline-flex min-w-0 items-center gap-1 font-semibold hover:text-primary" title={t('wellbeing.kit.regionProfile')}>
              <span className="truncate">{name}</span>
              <ArrowUpRight className="h-3.5 w-3.5 shrink-0 opacity-50 transition-opacity group-hover:opacity-100" />
            </Link>
          ) : (
            <span className="truncate font-semibold">{name}</span>
          )}
        </span>
        <span className="text-[0.7rem] text-muted-foreground">{t('wellbeing.problems.aboveCount', { count: hotspot.aboveCount, total })}</span>
      </div>
      <ul className="mt-2 flex flex-wrap gap-1.5">
        {hotspot.signals.map((s) => (
          <li key={s.metric} className="inline-flex items-center gap-1.5 rounded-full bg-amber-500/10 px-2.5 py-1 text-[0.72rem] ring-1 ring-inset ring-amber-500/25">
            <span className="text-foreground/85">{t(problemLabelKey(s.metric))}</span>
            <b className="font-semibold tabular-nums">{fmt.value(s.metric, s.value)}</b>
            <span className="tabular-nums text-amber-700 dark:text-amber-300">{fmt.delta(s.metric, s.diff)}</span>
          </li>
        ))}
      </ul>
    </li>
  );
}

/** Signallari o'rtachadan ko'p bo'lgan hududlar (yoki tumanlar) — resurslarni rejalashtirish uchun. */
export function HotspotsPanel({ scope, hotspots, total }: { scope: Scope; hotspots: readonly Hotspot[]; total: number }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const can = useCan();
  const national = scope.kind === 'NATIONAL';
  const linkable = national && can('regions.view');
  // Chegaralar — tahlildagi konstantalardan, chiplar bilan bir xil birlikda (p.p.).
  const thresholds = { pp: `${fmt.num(NOTABLE_MIN_DIFF, 1)} ${t('common.units.pp')}`, rel: fmt.pct(NOTABLE_EXCESS * 100, 0) };
  return (
    <div className="min-w-0">
      <BlockTitle className="mb-3">{national ? t('wellbeing.problems.hotspots') : t('wellbeing.problems.hotspotsDistrict')}</BlockTitle>
      {hotspots.length === 0 ? (
        <p className="rounded-xl bg-primary/[0.04] p-4 text-[0.82rem] text-muted-foreground ring-1 ring-inset ring-border/50">
          {national ? t('wellbeing.problems.noHotspots') : t('wellbeing.problems.noHotspotsDistrict')}
        </p>
      ) : (
        <ol className="space-y-2">
          {hotspots.map((h, i) => (
            <HotspotCard key={h.id} hotspot={h} rank={i + 1} total={total} linkable={linkable} />
          ))}
        </ol>
      )}
      <p className="mt-3 text-[0.72rem] text-muted-foreground">
        {hotspots.length > 0 && <>{t('wellbeing.problems.hotspotsHint')} </>}
        {national ? t('wellbeing.problems.avgNote', thresholds) : t('wellbeing.problems.avgNoteDistrict', thresholds)}
      </p>
    </div>
  );
}
