'use client';

import { Badge } from '@/components/ui/badge';
import type { ScaleScore, StudentDevProfile } from '@/data/contracts';
import { type TKey, useI18n } from '@/i18n';
import { hasKey } from '@/i18n/translate';
import { BandChip } from './band-chip';

type Result = StudentDevProfile['results'][number];

function ScaleLine({ scale }: { scale: ScaleScore }) {
  const { t, locale } = useI18n();
  const key = `development.scales.${scale.key}`;
  const label = hasKey(locale, key) ? t(key as TKey) : scale.key;
  return (
    <span className="inline-flex items-center gap-1.5 whitespace-nowrap text-xs">
      <span className="text-muted-foreground">{label}</span>
      {scale.standard !== null && <span className="font-semibold tabular-nums">{scale.standard}</span>}
      <span className="tabular-nums text-muted-foreground/80">
        ({t('development.raw')} {scale.raw}
        {scale.max !== null ? `/${scale.max}` : ''})
      </span>
      {scale.band && <BandChip band={scale.band} />}
    </span>
  );
}

/** Psixolog uchun: barcha natijalar, xom ball va javoblar bilan (yangisi birinchi). */
export function ResultsTable({ results }: { results: Result[] }) {
  const { t, locale, formatDate } = useI18n();
  return (
    <div className="-mx-1 overflow-x-auto px-1">
      <table className="w-full min-w-[760px] text-sm">
        <thead>
          <tr className="text-left text-xs text-muted-foreground">
            <th scope="col" className="pb-2 pl-1 font-medium">{t('development.profile.test')}</th>
            <th scope="col" className="pb-2 px-2 font-medium">{t('development.profile.date')}</th>
            <th scope="col" className="pb-2 px-2 font-medium">{t('development.profile.scales')}</th>
            <th scope="col" className="pb-2 px-2 font-medium">{t('development.profile.duration')}</th>
            <th scope="col" className="pb-2 px-2 font-medium">{t('development.profile.answers')}</th>
          </tr>
        </thead>
        <tbody>
          {results.map((r) => (
            <tr key={r.id} className="border-t border-border/50 align-top dark:border-white/[0.06]">
              <th scope="row" className="py-2.5 pl-1 pr-2 text-left font-medium">
                {r.testTitle[locale]}
                <Badge variant="outline" size="sm" className="ml-2 align-middle">{t(`development.profile.origin.${r.origin}`)}</Badge>
              </th>
              <td className="whitespace-nowrap px-2 py-2.5 text-xs tabular-nums text-muted-foreground">{formatDate(r.takenAt, 'd MMM yyyy')}</td>
              <td className="px-2 py-2">
                <div className="flex flex-col gap-1">
                  {r.topCodes ? (
                    <span className="text-xs">
                      <span className="font-semibold">{r.topCodes}</span>{' '}
                      <span className="tabular-nums text-muted-foreground">{Object.entries(r.raw).map(([k, v]) => `${k}${v}`).join(' ')}</span>
                    </span>
                  ) : (
                    r.scales.map((s) => <ScaleLine key={s.key} scale={s} />)
                  )}
                </div>
              </td>
              <td className="whitespace-nowrap px-2 py-2.5 text-xs tabular-nums text-muted-foreground">
                {r.durationSec ? t('development.profile.minutes', { n: Math.max(1, Math.round(r.durationSec / 60)) }) : '—'}
              </td>
              <td className="max-w-[10rem] px-2 py-2.5">
                {r.answers ? (
                  <code className="block truncate rounded-md bg-primary/[0.06] px-1.5 py-0.5 font-mono text-[0.7rem]" title={r.answers}>{r.answers}</code>
                ) : (
                  <span className="text-xs text-muted-foreground">—</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
