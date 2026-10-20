'use client';

import type { ScoreBand } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { bandLongKey, bandShortKey, bandTone } from '../lib/domains';

/** Daraja belgisi: qisqa yorliq, to'liq (qo'llab-quvvatlovchi) matn — sarlavhada. */
export function BandChip({ band, index, className }: { band: ScoreBand | null | undefined; index?: number | null; className?: string }) {
  const { t } = useI18n();
  if (!band) return <span className="text-xs text-muted-foreground">{t('development.noValue')}</span>;
  return (
    <span
      title={t(bandLongKey(band))}
      className={cn('inline-flex items-center gap-1 whitespace-nowrap rounded-full px-2 py-0.5 text-[0.7rem] font-semibold ring-1 ring-inset', bandTone(band), className)}
    >
      {t(bandShortKey(band))}
      {typeof index === 'number' && <span className="tabular-nums opacity-70">· {index}</span>}
    </span>
  );
}
