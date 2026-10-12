'use client';

import { ScreeningDisclaimer } from '@/components/common/screening-disclaimer';
import type { DomainValue, StudentDevProfile } from '@/data/contracts';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { adviceKey, domainKey } from '../lib/domains';
import { BandChip } from './band-chip';

/** Mantiqiy fikrlash: oxirgi natijaning standart bali (100 ± 15). */
function reasoningStandard(value: DomainValue, results: StudentDevProfile['results']): number | null {
  const r = results.find((x) => x.takenAt === value.takenAt && x.scales.some((s) => s.standard !== null));
  return r?.scales.find((s) => s.standard !== null)?.standard ?? null;
}

function IndexBar({ index }: { index: number }) {
  return (
    <span className="relative mt-2 block h-1.5 overflow-hidden rounded-full bg-primary/10" aria-hidden>
      <span className="absolute inset-y-0 left-0 rounded-full bg-primary" style={{ width: `${index}%` }} />
      <span className="absolute inset-y-[-2px] left-1/2 w-px bg-foreground/30" />
    </span>
  );
}

/** Har soha: daraja, indeks (0..100) va qo'llab-quvvatlovchi tavsiya. */
export function DomainCards({ profile }: { profile: StudentDevProfile }) {
  const { t, formatDate } = useI18n();
  return (
    <ul className="grid gap-3 sm:grid-cols-2">
      {profile.latest.map((v) => {
        const standard = v.domain === 'REASONING' ? reasoningStandard(v, profile.results) : null;
        return (
          <li key={v.domain} className={cn(TILE, 'flex flex-col px-4 py-3.5', v.domain === 'REASONING' && 'sm:col-span-2')}>
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <p className="text-sm font-semibold">{v.domain === 'REASONING' ? t('development.iqLabel') : t(domainKey(v.domain))}</p>
                <p className="text-xs text-muted-foreground">
                  {v.domain === 'REASONING' ? t(domainKey(v.domain)) : t(`development.domainHint.${v.domain}`)}
                  {v.takenAt && ` · ${formatDate(v.takenAt, 'd MMM yyyy')}`}
                </p>
              </div>
              <BandChip band={v.band} />
            </div>
            {v.band === null ? (
              <p className="mt-2 text-xs text-muted-foreground">{t('development.profile.noData')}</p>
            ) : (
              <>
                {standard !== null && (
                  <p className="mt-2 flex items-baseline gap-2">
                    <span className="font-display text-2xl font-semibold tabular-nums">{standard}</span>
                    <span className="text-xs text-muted-foreground">{t('development.standard')} · {t('development.index')} {v.index ?? '—'}</span>
                  </p>
                )}
                {typeof v.index === 'number' && standard === null && (
                  <p className="mt-2 text-xs text-muted-foreground">
                    {t('development.index')} <span className="font-semibold tabular-nums text-foreground">{v.index}</span>/100
                  </p>
                )}
                {typeof v.index === 'number' && <IndexBar index={v.index} />}
                <p className="mt-2 text-xs leading-relaxed text-foreground/75">{t(adviceKey(v.band))}</p>
                {v.domain === 'REASONING' && <ScreeningDisclaimer withIq className="mt-2" />}
              </>
            )}
          </li>
        );
      })}
    </ul>
  );
}
