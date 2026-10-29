'use client';

import { Compass } from 'lucide-react';

import { ShareBars } from '@/components/charts/share-bars';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Interests, Scope } from '@/data/contracts';
import { RIASEC } from '@/data/reference/domains';
import { NATIONAL_COLOR } from '@/features/mastery/kit/colors';
import { Note, SubHeading } from '@/features/mastery/kit/layout';
import { useScopeLabels } from '@/features/mastery/kit/scope';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { RiasecRadar } from './riasec-radar';

const SCOPE_COLOR = 'hsl(199 90% 55%)';
/** Ballar ~45–60: radar shkalasi 0–80 (markaz — nol). */
const RADAR_MAX = 80;

function ScoreChips({ data, region }: { data: Interests; region: boolean }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <ul className="grid grid-cols-3 gap-2 sm:grid-cols-6">
      {data.riasec.map((r) => (
        <li key={r.code} className="rounded-lg bg-primary/[0.05] px-2 py-1.5 text-center ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]" title={t(`enums.riasec.${r.code}`)}>
          <p className="text-[0.66rem] font-semibold uppercase tracking-[0.1em] text-muted-foreground">{r.code}</p>
          <p className="text-[0.9rem] font-semibold tabular-nums">{r.score === null ? '—' : fmt.num(r.score, 1)}</p>
          {region && <p className="text-[0.64rem] tabular-nums text-muted-foreground">{r.national === null ? '—' : fmt.num(r.national, 1)}</p>}
        </li>
      ))}
    </ul>
  );
}

/** RIASEC: radar (hudud doirasida — respublika bilan) va yetakchi tiplar ulushi. */
export function RiasecSection({ scope, data }: { scope: Scope; data: Interests | undefined }) {
  const { t } = useI18n();
  const { national, scopeName } = useScopeLabels(scope);
  const series = data
    ? [
        { key: 'scope', label: scopeName, values: Object.fromEntries(data.riasec.map((r) => [r.code, r.score])), color: SCOPE_COLOR },
        ...(national
          ? []
          : [{ key: 'national', label: t('common.nationalAvg'), values: Object.fromEntries(data.riasec.map((r) => [r.code, r.national])), color: NATIONAL_COLOR, dashed: true }]),
      ]
    : [];
  return (
    <Section id="interests-riasec" icon={<Compass />} title={t('interests.sections.riasec')} subtitle={t('interests.sections.riasecSub')}>
      {!data ? (
        <Skeleton className="h-[420px] w-full rounded-xl" />
      ) : (
        <div className="grid gap-8 lg:grid-cols-2">
          <div className="space-y-4">
            <SubHeading>{t('interests.riasec.scores')}</SubHeading>
            {/* Keng ekranda — to'liq nomlar, telefonda — kod harflari (izohi pastdagi kartochkalarda). */}
            <RiasecRadar className="hidden sm:flex" size={300} max={RADAR_MAX} axes={RIASEC.map((code) => ({ key: code, label: t(`enums.riasec.${code}`) }))} series={series} />
            <RiasecRadar className="sm:hidden" size={300} max={RADAR_MAX} axes={RIASEC.map((code) => ({ key: code, label: code }))} series={series} />
            <ScoreChips data={data} region={!national} />
            {!national && <Note>{t('interests.riasec.chipsNote')}</Note>}
          </div>
          <div>
            <SubHeading>{t('interests.riasec.topShares')}</SubHeading>
            <ShareBars
              rows={data.riasecTop.map((r) => ({ key: r.key, label: `${t(`enums.riasec.${r.key}`)} (${r.key})`, share: r.share, hint: t(`enums.riasecHint.${r.key}`) }))}
              barClassName="bg-gradient-to-r from-sky-500 to-cyan-400"
            />
            <Note className="mt-3">{t('interests.riasec.topSharesNote')}</Note>
          </div>
        </div>
      )}
    </Section>
  );
}
