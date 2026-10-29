'use client';

import { Rows3 } from 'lucide-react';

import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Iq, Scope } from '@/data/contracts';
import { IQ_BAND_COLORS } from '@/features/dashboard/learning-sections';
import { StackBar, SwatchLegend } from '@/features/mastery/kit/bars';
import { Note } from '@/features/mastery/kit/layout';
import { csvNumber } from '@/features/mastery/kit/num';
import { useAreaDrill, useScopeLabels } from '@/features/mastery/kit/scope';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { downloadCsv } from '@/lib/csv';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import { IQ_BANDS_ASC } from './iq-norm';

type AreaRow = Iq['byArea'][number];

const COLS_MEAN = 'sm:grid-cols-[minmax(0,10rem)_minmax(0,1fr)_4.75rem_4.5rem]';
const COLS_NO_MEAN = 'sm:grid-cols-[minmax(0,10rem)_minmax(0,1fr)_4.75rem]';

function AreaBandRow({ row, normed, onOpen }: { row: AreaRow; normed: boolean; onOpen?: (id: string) => void }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const Row = onOpen ? 'button' : 'div';
  const parts = IQ_BANDS_ASC.map((b) => ({ key: b, label: t(`enums.iqBand.${b}`), value: row.bands?.[b] ?? 0, color: IQ_BAND_COLORS[b] }));
  return (
    <Row
      {...(onOpen ? { type: 'button' as const, onClick: () => onOpen(row.id) } : {})}
      className={cn(
        'grid w-full grid-cols-[minmax(0,1fr)_auto] items-center gap-x-3 gap-y-1.5 rounded-lg px-2 py-1.5 text-left text-[0.8rem]',
        normed ? COLS_MEAN : COLS_NO_MEAN,
        onOpen && 'transition-colors hover:bg-primary/[0.06] focus-visible:bg-primary/[0.06]',
      )}
    >
      <span className="truncate font-medium">{areaName(row.id, { short: true, fallback: row.name })}</span>
      <span className="col-span-2 row-start-2 sm:col-span-1 sm:row-start-auto">
        {row.bands ? <StackBar parts={parts} /> : <span className="text-[0.72rem] text-muted-foreground">—</span>}
      </span>
      <span className="text-right tabular-nums text-muted-foreground">{fmt.value('iqParticipation', row.participation)}</span>
      {normed && <span className="hidden text-right font-semibold tabular-nums sm:block">{fmt.value('iqMean', row.mean)}</span>}
    </Row>
  );
}

/** CSV: bo'linma, qamrov, (o'rtacha ball), darajalar ulushi. */
function useAreasCsv(data: Iq | undefined, areasHeader: string) {
  const { t } = useI18n();
  const areaName = useAreaName();
  return () => {
    if (!data) return;
    downloadCsv(t('iq.areas.csvName'), data.byArea, [
      { header: areasHeader, value: (r: AreaRow) => areaName(r.id, { fallback: r.name }) },
      { header: t('iq.areas.colParticipation'), value: (r: AreaRow) => csvNumber(r.participation) },
      ...(data.normed ? [{ header: t('iq.areas.colMean'), value: (r: AreaRow) => csvNumber(r.mean) }] : []),
      ...IQ_BANDS_ASC.map((b) => ({ header: t(`enums.iqBand.${b}`), value: (r: AreaRow) => csvNumber(r.bands?.[b]) })),
    ]);
  };
}

/** Hududlar (yoki tumanlar) bo'yicha daraja taqsimoti — rasmiy tartibda (reyting emas). */
export function IqAreasSection({ scope, data }: { scope: Scope; data: Iq | undefined }) {
  const { t } = useI18n();
  const drill = useAreaDrill(scope);
  const { national, areasHeader } = useScopeLabels(scope);
  const normed = data?.normed ?? false;
  const exportCsv = useAreasCsv(data, areasHeader);
  const head = 'text-[0.66rem] font-semibold uppercase tracking-[0.08em] text-muted-foreground';

  return (
    <Section
      id="iq-areas"
      icon={<Rows3 />}
      title={national ? t('iq.sections.areasRegions') : t('iq.sections.areasDistricts')}
      subtitle={t('iq.sections.areasSub')}
      actions={<ExportMenu onCsv={exportCsv} disabled={!data} />}
    >
      {!data ? (
        <Skeleton className="h-[520px] w-full rounded-xl" />
      ) : (
        <div className="space-y-3">
          <SwatchLegend items={IQ_BANDS_ASC.map((b) => ({ key: b, label: `${t(`enums.iqBand.${b}`)} (${t(`iq.ranges.${b}`)})`, color: IQ_BAND_COLORS[b] }))} />
          <div className={cn('hidden gap-x-3 px-2 pt-1 sm:grid', normed ? COLS_MEAN : COLS_NO_MEAN)}>
            <span className={head}>{areasHeader}</span>
            <span className={head}>{t('iq.areas.colBands')}</span>
            <span className={cn(head, 'text-right')}>{t('iq.areas.colParticipation')}</span>
            {normed && <span className={cn(head, 'text-right')}>{t('iq.areas.colMean')}</span>}
          </div>
          <ul className="space-y-0.5">
            {data.byArea.map((row) => (
              <li key={row.id}>
                <AreaBandRow row={row} normed={normed} onOpen={drill} />
              </li>
            ))}
          </ul>
          <Note>
            {t('common.screening.regionsNote')} {drill ? t('iq.areas.hintClick') : ''}
          </Note>
        </div>
      )}
    </Section>
  );
}
