'use client';

import { HandHeart } from 'lucide-react';
import type { ReactNode } from 'react';

import { DeltaChip } from '@/components/charts/delta-chip';
import { ShareBars } from '@/components/charts/share-bars';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Wellbeing } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { BlockTitle } from './kit/chart-block';

function MiniStat({ label, value, extra }: { label: string; value: string; extra?: ReactNode }) {
  return (
    <div className="rounded-xl bg-primary/[0.05] px-3 py-2.5 ring-1 ring-inset ring-border/50 dark:bg-white/[0.03]">
      <p className="line-clamp-2 min-h-[2.2em] text-[0.7rem] leading-snug text-muted-foreground">{label}</p>
      <div className="mt-1 flex flex-wrap items-baseline gap-2">
        <span className="font-display text-lg font-semibold tabular-nums">{value}</span>
        {extra}
      </div>
    </div>
  );
}

/** Psixologga murojaatlar: daraja, shoshilinch ulush, SOS va mavzular (faqat agregat). */
export function CarePanel({ id, data }: { id: string; data: Wellbeing | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (
    <Section id={id} className="scroll-mt-32" icon={<HandHeart />} title={t('wellbeing.care.title')} subtitle={t('wellbeing.care.subtitle')}>
      {!data ? (
        <Skeleton className="h-[360px] w-full rounded-xl" />
      ) : (
        <div className="space-y-5">
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <MiniStat
              label={t('wellbeing.care.rate')}
              value={fmt.value('careRequests', data.careRequests.value)}
              extra={<DeltaChip metric="careRequests" delta={data.careRequests.delta} title={t('common.vsLastYear')} />}
            />
            <MiniStat label={t('wellbeing.care.urgent')} value={fmt.pct(data.urgentShare)} />
            <MiniStat label={t('wellbeing.care.sos')} value={data.sos === null ? '—' : fmt.num(data.sos, 2)} />
          </div>
          <div>
            <BlockTitle className="mb-2.5">{t('wellbeing.care.topics')}</BlockTitle>
            <ShareBars
              rows={data.careTopics.map((c) => ({ key: c.key, label: t(`enums.careTopic.${c.key}`), share: c.share }))}
              barClassName="bg-gradient-to-r from-sky-500 to-cyan-400"
            />
          </div>
          <div className="space-y-1 text-[0.72rem] text-muted-foreground">
            <p>{t('wellbeing.care.trustNote')}</p>
            <p>{t('wellbeing.care.sosNote')}</p>
          </div>
        </div>
      )}
    </Section>
  );
}
