'use client';

import { Rows3 } from 'lucide-react';

import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Iq, Scope } from '@/data/contracts';
import { StackBar, SwatchLegend } from '@/features/mastery/kit/bars';
import { Note } from '@/features/mastery/kit/layout';
import { csvNumber } from '@/features/mastery/kit/num';
import { useAreaDrill, useScopeLabels } from '@/features/mastery/kit/scope';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { IQ_BAND_COLORS } from '@/lib/color-scale';
import { downloadCsv } from '@/lib/csv';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';
import { hasAreaBands, IQ_BANDS_ASC } from './iq-norm';

type AreaRow = Iq['byArea'][number];

const COLS_MEAN = 'sm:grid-cols-[minmax(0,10rem)_minmax(0,1fr)_4.75rem_4.5rem]';
const COLS_NO_MEAN = 'sm:grid-cols-[minmax(0,10rem)_minmax(0,1fr)_4.75rem]';
const HEAD = 'text-[0.66rem] font-semibold uppercase tracking-[0.08em] text-muted-foreground';

/** Qator ustuni nomi: ekran o'quvchisi uchun (keng ekranda sarlavha qatori ko'rinadi). */
function CellLabel({ children, visibleOnPhone = false }: { children: string; visibleOnPhone?: boolean }) {
  return <span className={visibleOnPhone ? 'text-muted-foreground/80 sm:sr-only' : 'sr-only'}>{children} </span>;
}

function AreaBands({ row }: { row: AreaRow }) {
  const { t } = useI18n();
  if (!hasAreaBands(row.bands)) return <span className="text-[0.72rem] text-muted-foreground">—</span>;
  const bands = row.bands;
  return <StackBar parts={IQ_BANDS_ASC.map((b) => ({ key: b, label: t(`enums.iqBand.${b}`), value: bands[b], color: IQ_BAND_COLORS[b] }))} />;
}

function AreaBandRow({ row, normed, onOpen }: { row: AreaRow; normed: boolean; onOpen?: (id: string) => void }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const Row = onOpen ? 'button' : 'div';
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
        <CellLabel>{`${t('iq.areas.colBands')}:`}</CellLabel>
        <AreaBands row={row} />
      </span>
      <span className="text-right tabular-nums text-muted-foreground">
        <CellLabel visibleOnPhone>{t('iq.areas.colParticipation')}</CellLabel>
        {fmt.value('iqParticipation', row.participation)}
      </span>
      {normed && (
        <span className="hidden text-right font-semibold tabular-nums sm:block">
          <CellLabel>{`${t('iq.areas.colMean')}:`}</CellLabel>
          {fmt.value('iqMean', row.mean)}
        </span>
      )}
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

/** Keng ekrandagi ustun sarlavhalari — faqat ko'rinish uchun (qatorlarda ekran o'quvchisi uchun yorliqlar bor). */
function AreasHeader({ normed, areasHeader }: { normed: boolean; areasHeader: string }) {
  const { t } = useI18n();
  return (
    <div aria-hidden className={cn('hidden gap-x-3 px-2 pt-1 sm:grid', normed ? COLS_MEAN : COLS_NO_MEAN)}>
      <span className={HEAD}>{areasHeader}</span>
      <span className={HEAD}>{t('iq.areas.colBands')}</span>
      <span className={cn(HEAD, 'text-right')}>{t('iq.areas.colParticipation')}</span>
      {normed && <span className={cn(HEAD, 'text-right')}>{t('iq.areas.colMean')}</span>}
    </div>
  );
}

/** Hududlar (yoki tumanlar) bo'yicha daraja taqsimoti — rasmiy tartibda (reyting emas). */
export function IqAreasSection({ scope, data }: { scope: Scope; data: Iq | undefined }) {
  const { t } = useI18n();
  const drill = useAreaDrill(scope);
  const { national, areasHeader } = useScopeLabels(scope);
  const exportCsv = useAreasCsv(data, areasHeader);

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
          <AreasHeader normed={data.normed} areasHeader={areasHeader} />
          <ul className="space-y-0.5" aria-label={areasHeader}>
            {data.byArea.map((row) => (
              <li key={row.id}>
                <AreaBandRow row={row} normed={data.normed} onOpen={drill} />
              </li>
            ))}
          </ul>
          {drill && <Note>{t('iq.areas.hintClick')}</Note>}
        </div>
      )}
    </Section>
  );
}
