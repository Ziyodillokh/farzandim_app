'use client';

import { useCallback } from 'react';

import { api } from '@/data/api';
import type { Filters, MetricKey, Scope } from '@/data/contracts';
import { METRIC_KEYS, METRICS } from '@/data/mock/model/metrics';
import { PROBLEM_METRICS } from '@/data/mock/services/overview';
import { IQ_DISPLAY_BANDS, SUBJECT_KEYS } from '@/data/reference/domains';
import { regionName, regionRef } from '@/data/reference/regions';
import { useI18n } from '@/i18n';
import { useAreaName } from '@/lib/area-name';
import { type CsvColumn, csvDecimal } from '@/lib/csv';

export const DATASET_KEYS = ['indicators', 'mastery', 'problems', 'iq', 'interests', 'schools'] as const;
export type DatasetKey = (typeof DATASET_KEYS)[number];

type Cell = string | number | null;
type Row = Record<string, Cell>;
export type BuiltDataset = { filename: string; rows: Row[]; columns: CsvColumn<Row>[] };

const csvNum = csvDecimal;

const col = (key: string, header: string): CsvColumn<Row> => ({ header, value: (r) => r[key] ?? null });

function scopeSlug(scope: Scope): string {
  return scope.kind === 'NATIONAL' ? 'respublika' : regionRef(scope.regionId).slug;
}

function today(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** CSV to'plamlarini tayyorlash: joriy doira va filtrlar bo'yicha, bosilganda hisoblanadi. */
export function useDatasetBuilder() {
  const { t, locale } = useI18n();
  const areaName = useAreaName();

  const unitLabel = useCallback(
    (key: MetricKey): string => {
      const unit = METRICS[key].unit;
      const map = {
        '%': '%',
        min: t('common.units.min'),
        per1000: t('common.units.per1000'),
        index: t('common.units.index'),
        score: t('common.units.score'),
        perWeek: t('common.units.perWeek'),
        steps: t('common.units.steps'),
      } as const;
      return `${t(`metrics.${key}.label`)}, ${map[unit]}`;
    },
    [t],
  );

  return useCallback(
    async (key: DatasetKey, scope: Scope, f: Filters): Promise<BuiltDataset> => {
      const national = scope.kind === 'NATIONAL';
      const areaHeader = national ? t('reports.col.region') : t('reports.col.district');
      const label = (id: string, fallback: string) => areaName(id, { fallback });
      const filename = `parvoz-monitoring-DEMO_${key}_${scopeSlug(scope)}_${f.period.toLowerCase()}_${today()}.csv`;

      const matrix = async (metrics: readonly MetricKey[]) => {
        const m = await api.areaMatrix(metrics, scope, f);
        const rows = m.rows.map((r) => {
          const row: Row = { area: label(r.id, r.name), official: r.official, covered: r.covered };
          for (const k of metrics) {
            const s = r.values[k];
            row[k] = csvNum(s?.value, METRICS[k].decimals);
            row[`${k}:d`] = csvNum(s?.delta, METRICS[k].decimals);
          }
          return row;
        });
        const columns = [
          col('area', areaHeader),
          col('official', t('reports.col.official')),
          col('covered', t('reports.col.covered')),
          ...metrics.flatMap((k) => [col(k, unitLabel(k)), col(`${k}:d`, `${t(`metrics.${k}.label`)}: ${t('reports.col.change')}`)]),
        ];
        return { filename, rows, columns };
      };

      switch (key) {
        case 'indicators':
          return matrix(METRIC_KEYS);
        case 'problems':
          return matrix(PROBLEM_METRICS);
        case 'mastery': {
          const m = await api.mastery(scope, f);
          const rows = m.heat.map((r) => ({
            area: label(r.id, r.name),
            overall: csvNum(r.overall),
            ...Object.fromEntries(SUBJECT_KEYS.map((s) => [s, csvNum(r.values[s])])),
          }));
          const columns = [
            col('area', areaHeader),
            col('overall', `${t('reports.col.overall')}, %`),
            ...SUBJECT_KEYS.map((s) => col(s, `${t(`enums.subject.${s}`)}, %`)),
          ];
          return { filename, rows, columns };
        }
        case 'iq': {
          const iq = await api.iq(scope, f);
          const rows = iq.byArea.map((r) => ({
            area: label(r.id, r.name),
            participation: csvNum(r.participation),
            mean: csvNum(r.mean),
            ...Object.fromEntries(IQ_DISPLAY_BANDS.map((b) => [b, csvNum(r.bands?.[b] ?? null)])),
          }));
          const columns = [
            col('area', areaHeader),
            col('participation', t('reports.col.participation')),
            col('mean', t('reports.col.mean')),
            ...IQ_DISPLAY_BANDS.map((b) => col(b, `${t(`enums.iqBand.${b}`)}, %`)),
          ];
          return { filename, rows, columns };
        }
        case 'interests': {
          const it = await api.interests(scope, f);
          const rows = it.byArea.map((r) => ({
            area: label(r.id, r.name),
            topSubject: r.topSubject ? t(`enums.subject.${r.topSubject}`) : null,
            topSubjectShare: csvNum(r.topSubjectShare),
            topCode: r.topCode ? `${r.topCode} — ${t(`enums.riasec.${r.topCode}`)}` : null,
            topField: r.topField ? t(`enums.careerField.${r.topField}`) : null,
          }));
          const columns = [
            col('area', areaHeader),
            col('topSubject', t('reports.col.topSubject')),
            col('topSubjectShare', t('reports.col.topSubjectShare')),
            col('topCode', t('reports.col.topCode')),
            col('topField', t('reports.col.topField')),
          ];
          return { filename, rows, columns };
        }
        case 'schools': {
          const s = await api.schools(scope, f);
          const list = (name: string, items: typeof s.topGrowth) =>
            items.map((r) => ({
              list: name,
              code: r.code,
              region: regionName(r.regionId, locale),
              district: areaName(r.districtId, { fallback: r.districtName }),
              type: t(`enums.schoolType.${r.type}`),
              pupils: r.pupils,
              mastery: csvNum(r.mastery),
              growth: csvNum(r.growth),
              attendance: csvNum(r.attendance),
              wellbeing: csvNum(r.wellbeing, 0),
            }));
          const rows = [...list(t('reports.lists.topGrowth'), s.topGrowth), ...list(t('reports.lists.needSupport'), s.needSupport)];
          const columns = (['list', 'code', 'region', 'district', 'type', 'pupils', 'mastery', 'growth', 'attendance', 'wellbeing'] as const).map((k) =>
            col(k, t(`reports.col.${k}`)),
          );
          return { filename, rows, columns };
        }
      }
    },
    [t, locale, areaName, unitLabel],
  );
}
