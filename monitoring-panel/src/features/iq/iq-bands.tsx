'use client';

import { ChartColumnBig } from 'lucide-react';

import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Iq } from '@/data/contracts';
import type { IqDisplayBand } from '@/data/reference/domains';
import { IQ_BAND_COLORS } from '@/lib/color-scale';
import { Inset, Note } from '@/features/mastery/kit/layout';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { bandShare, IQ_BANDS_ASC, IQ_NORM_SHARE, maxNormDeviation, NORM_CLOSE_PP } from './iq-norm';

/** Ustun balandligi — bo'yi 82% gacha (yorliq uchun joy qoladi). */
const BAR_SPACE = 82;

function useBandLabels() {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return (band: IqDisplayBand, share: number) =>
    t('iq.bands.shareTitle', { band: t(`enums.iqBand.${band}`), range: t(`iq.ranges.${band}`), value: fmt.pct(share), norm: fmt.pct(IQ_NORM_SHARE[band]) });
}

/** Taqsimot gistogrammasi: ustun — haqiqiy ulush, uzuq chiziq — yosh normasi bo'yicha kutilgan ulush. */
function BandHistogram({ bands }: { bands: Iq['bands'] }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const title = useBandLabels();
  const max = Math.max(1, ...IQ_BANDS_ASC.map((b) => Math.max(bandShare(bands, b), IQ_NORM_SHARE[b])));
  const h = (v: number) => (v / max) * BAR_SPACE;
  return (
    <figure>
      <div className="grid h-[240px] grid-cols-6 gap-2 border-b border-border/80 sm:gap-4" role="img" aria-label={t('iq.sections.bands')}>
        {IQ_BANDS_ASC.map((b) => {
          const share = bandShare(bands, b);
          const norm = IQ_NORM_SHARE[b];
          return (
            <div key={b} className="relative flex items-end justify-center" title={title(b, share)}>
              <span
                className="absolute inset-x-0 text-center text-[0.74rem] font-semibold tabular-nums"
                style={{ bottom: `calc(${h(Math.max(share, norm))}% + 6px)` }}
              >
                {fmt.pct(share)}
              </span>
              <span className="w-full max-w-[64px] rounded-t-md transition-[height] duration-700" style={{ height: `${h(share)}%`, background: IQ_BAND_COLORS[b] }} />
              <span aria-hidden className="absolute left-1/2 w-full max-w-[76px] -translate-x-1/2 border-t-2 border-dashed border-foreground/60" style={{ bottom: `${h(norm)}%` }} />
            </div>
          );
        })}
      </div>
      <div className="mt-2 grid grid-cols-6 gap-2 text-center sm:gap-4">
        {IQ_BANDS_ASC.map((b) => (
          <div key={b} className="min-w-0">
            <p className="whitespace-nowrap text-[0.62rem] font-semibold tabular-nums tracking-tight sm:text-[0.74rem] sm:tracking-normal">{t(`iq.ranges.${b}`)}</p>
            <p className="hidden text-[0.68rem] leading-tight text-muted-foreground sm:block">{t(`enums.iqBand.${b}`)}</p>
          </div>
        ))}
      </div>
      <figcaption className="mt-3 flex items-center gap-2 text-[0.72rem] text-muted-foreground">
        <span aria-hidden className="w-5 border-t-2 border-dashed border-foreground/60" />
        {t('iq.bands.normLegend')}
      </figcaption>
    </figure>
  );
}

/** Jadval ko'rinishi: daraja, ball oralig'i, ulush, yillik o'zgarish va norma. */
function BandTable({ bands }: { bands: Iq['bands'] }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const head = 'pb-2 text-[0.66rem] font-semibold uppercase tracking-[0.08em] text-muted-foreground';
  return (
    <table className="w-full text-[0.8rem]">
      <thead>
        <tr>
          <th className={`${head} text-left`}>{t('iq.bands.colBand')}</th>
          <th className={`${head} text-right`}>{t('iq.bands.colShare')}</th>
          <th className={`${head} pl-3 text-right`}>{t('iq.bands.colChange')}</th>
          <th className={`${head} pl-3 text-right`}>{t('iq.bands.colNorm')}</th>
        </tr>
      </thead>
      <tbody>
        {[...IQ_BANDS_ASC].reverse().map((b) => {
          const item = bands.find((x) => x.key === b);
          return (
            <tr key={b} className="border-t border-border/50">
              <td className="py-2 pr-2">
                <span className="flex min-w-0 items-center gap-2">
                  <span aria-hidden className="h-2.5 w-2.5 shrink-0 rounded-sm" style={{ background: IQ_BAND_COLORS[b] }} />
                  <span className="min-w-0">
                    <span className="block font-medium leading-tight">{t(`enums.iqBand.${b}`)}</span>
                    <span className="block text-[0.68rem] tabular-nums text-muted-foreground">{t(`iq.ranges.${b}`)}</span>
                  </span>
                </span>
              </td>
              <td className="py-2 text-right font-semibold tabular-nums">{fmt.pct(item?.share ?? 0)}</td>
              <td className="py-2 text-right tabular-nums text-muted-foreground">{fmt.delta('iqHigh', item?.delta ?? null)}</td>
              <td className="py-2 pl-3 text-right tabular-nums text-muted-foreground">{fmt.pct(IQ_NORM_SHARE[b])}</td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}

function NormVerdict({ bands }: { bands: Iq['bands'] }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const dev = maxNormDeviation(bands);
  if (!dev) return null;
  const value = fmt.delta('iqHigh', dev.diff);
  return (
    <Inset className="py-2.5 text-[0.8rem]">
      {Math.abs(dev.diff) < NORM_CLOSE_PP ? t('iq.bands.close', { value }) : t('iq.bands.far', { band: t(`enums.iqBand.${dev.band}`), value })}
    </Inset>
  );
}

/** Daraja taqsimoti: gistogramma (norma bilan) + jadval ko'rinishi. */
export function IqBandsSection({ data }: { data: Iq | undefined }) {
  const { t } = useI18n();
  return (
    <Section id="iq-bands" icon={<ChartColumnBig />} title={t('iq.sections.bands')} subtitle={t('iq.sections.bandsSub')}>
      {!data ? (
        <Skeleton className="h-[340px] w-full rounded-xl" />
      ) : (
        <div className="grid gap-6 xl:grid-cols-[minmax(0,1.35fr)_minmax(0,1fr)]">
          <BandHistogram bands={data.bands} />
          <div className="space-y-3">
            <BandTable bands={data.bands} />
            <NormVerdict bands={data.bands} />
            <Note>{t('common.screening.notIq')}</Note>
          </div>
        </div>
      )}
    </Section>
  );
}
