'use client';

import { TableProperties } from 'lucide-react';

import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Interests, Scope } from '@/data/contracts';
import { Note } from '@/features/mastery/kit/layout';
import { csvNumber } from '@/features/mastery/kit/num';
import { useAreaDrill, useScopeLabels } from '@/features/mastery/kit/scope';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { downloadCsv } from '@/lib/csv';
import { useMetricFormat } from '@/lib/format';
import { cn } from '@/lib/utils';

type AreaRow = Interests['byArea'][number];

const TH = 'px-3 py-2 text-left text-[0.66rem] font-semibold uppercase tracking-[0.08em] text-muted-foreground';
const TD = 'border-t border-border/40 px-3 py-2';

function CodeBadge({ code }: { code: string }) {
  return (
    <span aria-hidden className="inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-md bg-primary/10 text-[0.68rem] font-bold text-primary ring-1 ring-inset ring-primary/20">
      {code}
    </span>
  );
}

/**
 * Jadval qatori. Bosiladigan bo'lsa (hudud profili) — sichqoncha uchun butun qator,
 * klaviatura va ekran o'quvchisi uchun qator sarlavhasidagi tugma (umumiy
 * `HeatTable` bilan bir xil).
 */
function AreaTableRow({ row, onOpen }: { row: AreaRow; onOpen?: (id: string) => void }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const name = areaName(row.id, { short: true, fallback: row.name });
  return (
    <tr onClick={onOpen ? () => onOpen(row.id) : undefined} className={cn('group', onOpen && 'cursor-pointer')}>
      <th scope="row" className={cn(TD, 'sticky left-0 z-10 whitespace-nowrap bg-card/95 text-left font-medium backdrop-blur group-hover:text-primary')}>
        {onOpen ? (
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              onOpen(row.id);
            }}
            className="rounded text-left font-medium outline-none hover:text-primary focus-visible:ring-2 focus-visible:ring-ring"
          >
            {name}
          </button>
        ) : (
          name
        )}
      </th>
      <td className={TD}>
        {row.topSubject ? (
          <span className="flex items-baseline gap-2">
            <span className="font-medium">{t(`enums.subject.${row.topSubject}`)}</span>
            <span className="text-[0.75rem] tabular-nums text-muted-foreground">{fmt.pct(row.topSubjectShare)}</span>
          </span>
        ) : (
          '—'
        )}
      </td>
      <td className={TD}>
        {row.topCode ? (
          <span className="flex items-center gap-2">
            <CodeBadge code={row.topCode} />
            {t(`enums.riasec.${row.topCode}`)}
          </span>
        ) : (
          '—'
        )}
      </td>
      <td className={TD}>{row.topField ? t(`enums.careerField.${row.topField}`) : '—'}</td>
    </tr>
  );
}

/** CSV: bo'linma, yetakchi fan (ulushi bilan), tip va soha. */
function useAreasCsv(data: Interests | undefined, areasHeader: string) {
  const { t } = useI18n();
  const areaName = useAreaName();
  return () => {
    if (!data) return;
    downloadCsv(t('interests.areas.csvName'), data.byArea, [
      { header: areasHeader, value: (r: AreaRow) => areaName(r.id, { fallback: r.name }) },
      { header: t('interests.areas.colTopSubject'), value: (r: AreaRow) => (r.topSubject ? t(`enums.subject.${r.topSubject}`) : '') },
      { header: t('interests.areas.csvShare'), value: (r: AreaRow) => csvNumber(r.topSubjectShare) },
      { header: t('interests.areas.colTopCode'), value: (r: AreaRow) => (r.topCode ? `${r.topCode} — ${t(`enums.riasec.${r.topCode}`)}` : '') },
      { header: t('interests.areas.colTopField'), value: (r: AreaRow) => (r.topField ? t(`enums.careerField.${r.topField}`) : '') },
    ]);
  };
}

/** Hududlar (tumanlar) bo'yicha yetakchi qiziqishlar jadvali + CSV. */
export function InterestsAreasSection({ scope, data }: { scope: Scope; data: Interests | undefined }) {
  const { t } = useI18n();
  const drill = useAreaDrill(scope);
  const { national, areasHeader } = useScopeLabels(scope);
  const exportCsv = useAreasCsv(data, areasHeader);

  return (
    <Section
      id="interests-areas"
      icon={<TableProperties />}
      title={national ? t('interests.sections.areasRegions') : t('interests.sections.areasDistricts')}
      subtitle={t('interests.sections.areasSub')}
      actions={<ExportMenu onCsv={exportCsv} disabled={!data} />}
    >
      {!data ? (
        <Skeleton className="h-[480px] w-full rounded-xl" />
      ) : (
        <>
          <div className="overflow-x-auto rounded-xl ring-1 ring-inset ring-border/50">
            <table className="w-full min-w-[620px] border-separate border-spacing-0 text-[0.8rem]">
              <thead>
                <tr>
                  <th scope="col" className={cn(TH, 'sticky left-0 z-10 bg-card/95 backdrop-blur')}>
                    {areasHeader}
                  </th>
                  <th scope="col" className={TH}>
                    {t('interests.areas.colTopSubject')}
                  </th>
                  <th scope="col" className={TH}>
                    {t('interests.areas.colTopCode')}
                  </th>
                  <th scope="col" className={TH}>
                    {t('interests.areas.colTopField')}
                  </th>
                </tr>
              </thead>
              <tbody>
                {data.byArea.map((row) => (
                  <AreaTableRow key={row.id} row={row} onOpen={drill} />
                ))}
              </tbody>
            </table>
          </div>
          {drill && <Note className="mt-2">{t('interests.areas.hintClick')}</Note>}
        </>
      )}
    </Section>
  );
}
