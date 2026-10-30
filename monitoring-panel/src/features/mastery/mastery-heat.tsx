'use client';

import { Grid3x3 } from 'lucide-react';

import { HeatTable } from '@/components/charts/heat-table';
import { ExportMenu } from '@/components/common/export-menu';
import { Section } from '@/components/common/section';
import { Skeleton } from '@/components/ui/skeleton';
import type { Mastery, Scope } from '@/data/contracts';
import { SUBJECT_KEYS } from '@/data/reference/domains';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { downloadCsv } from '@/lib/csv';
import { useMetricFormat } from '@/lib/format';
import { Note } from './kit/layout';
import { csvNumber } from './kit/num';
import { useAreaDrill, useScopeLabels } from './kit/scope';

type HeatRow = Mastery['heat'][number];

/** Umumiy natija bo'yicha kamayish tartibida; qiymatsizlar oxirida. */
function sortByOverall(rows: readonly HeatRow[]): HeatRow[] {
  return [...rows].sort((a, b) => (b.overall ?? -1) - (a.overall ?? -1));
}

/** Hududlar (yoki tumanlar) × fanlar issiqlik jadvali + CSV eksport. */
export function MasteryHeatSection({ scope, data }: { scope: Scope; data: Mastery | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const areaName = useAreaName();
  const drill = useAreaDrill(scope);
  const { national, areasHeader } = useScopeLabels(scope);
  const sorted = sortByOverall(data?.heat ?? []);
  // Tanlangan sinflarda o'qitilmaydigan fanlar ustuni (hamma katak bo'sh) ko'rsatilmaydi.
  const subjects = SUBJECT_KEYS.filter((s) => sorted.some((r) => r.values[s] !== null));
  const subjectLabel = (s: (typeof SUBJECT_KEYS)[number]) => t(`enums.subject.${s}`);

  const exportCsv = () =>
    downloadCsv(t('mastery.heat.csvName'), sorted, [
      { header: areasHeader, value: (r: HeatRow) => areaName(r.id, { fallback: r.name }) },
      { header: t('metrics.mastery.label'), value: (r: HeatRow) => csvNumber(r.overall) },
      ...subjects.map((s) => ({ header: subjectLabel(s), value: (r: HeatRow) => csvNumber(r.values[s]) })),
    ]);

  return (
    <Section
      id="mastery-heat"
      icon={<Grid3x3 />}
      title={national ? t('mastery.sections.heatRegions') : t('mastery.sections.heatDistricts')}
      subtitle={t('mastery.sections.heatSub')}
      actions={<ExportMenu onCsv={exportCsv} disabled={!data} />}
    >
      {!data ? (
        <Skeleton className="h-[520px] w-full rounded-xl" />
      ) : (
        <>
          <HeatTable
            columns={[{ key: 'overall', label: t('metrics.mastery.label') }, ...subjects.map((s) => ({ key: s, label: subjectLabel(s) }))]}
            minWidth={Math.min(720, 200 + subjects.length * 60)}
            rows={sorted.map((r) => ({ id: r.id, label: areaName(r.id, { short: true, fallback: r.name }), values: { ...r.values, overall: r.overall } }))}
            format={(v) => (v === null ? '—' : fmt.num(v, 0))}
            firstHeader={areasHeader}
            onRowClick={drill}
          />
          <Note className="mt-2">{drill ? t('mastery.heat.hintClick') : t('dashboard.heatHint')}</Note>
        </>
      )}
    </Section>
  );
}
