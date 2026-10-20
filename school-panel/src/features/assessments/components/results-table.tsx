'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';

import { type Column, DataTable } from '@/components/common/data-table';
import { Badge } from '@/components/ui/badge';
import type { PsychScale, PsychTestKind } from '@/data/contracts';
import type { ResultRow } from '@/data/mock/services/assessments';
import { useI18n } from '@/i18n';
import { BandBadge } from './test-badges';

const PAGE_SIZE = 20;

export const studentHref = (id: string) => `/students/view?id=${encodeURIComponent(id)}&tab=development`;

/** Shkala natijasi: standart ball / persentil / xom ball (kasbiy — yetakchi kodlar). */
export function ScoreCell({ row, scale, kind }: { row: ResultRow; scale: PsychScale | undefined; kind: PsychTestKind | undefined }) {
  const { t } = useI18n();
  if (kind === 'CAREER') {
    return <span className="font-mono text-sm font-semibold tracking-[0.2em] text-primary">{row.topCodes ?? '—'}</span>;
  }
  const s = row.scales.find((x) => x.key === scale?.key) ?? row.scales[0];
  if (!s) return <span className="text-muted-foreground">—</span>;
  const raw = s.raw !== undefined ? `${s.raw}${s.max ? ` / ${s.max}` : ''}` : null;
  if (scale?.display === 'STANDARD' && s.standard !== null && s.standard !== undefined) {
    return (
      <span className="flex items-baseline gap-2 tabular-nums">
        <span className="font-display text-base font-semibold">{s.standard}</span>
        {s.percentile !== null && s.percentile !== undefined && <span className="text-xs text-muted-foreground">P{s.percentile}</span>}
      </span>
    );
  }
  if (scale?.display === 'PERCENTILE' && s.percentile !== null && s.percentile !== undefined) {
    return <span className="font-semibold tabular-nums">{t('assessments.results.percentile', { value: s.percentile })}</span>;
  }
  return <span className="tabular-nums text-muted-foreground">{raw ?? '—'}</span>;
}

export function ResultsTable({
  rows,
  loading,
  scale,
  kind,
}: {
  rows: ResultRow[] | undefined;
  loading?: boolean;
  scale: PsychScale | undefined;
  kind: PsychTestKind | undefined;
}) {
  const { t, formatDate } = useI18n();
  const [page, setPage] = useState(1);
  const total = rows?.length ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  useEffect(() => setPage(1), [rows]);
  const visible = rows?.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const columns = useMemo<Column<ResultRow>[]>(
    () => [
      {
        key: 'student',
        header: t('assessments.results.columns.student'),
        cell: (r) => (
          <Link href={studentHref(r.studentId)} className="font-medium hover:text-primary hover:underline">
            {r.studentName}
          </Link>
        ),
      },
      { key: 'class', header: t('assessments.results.columns.class'), cell: (r) => <Badge variant="outline">{r.className}</Badge> },
      {
        key: 'date',
        header: t('assessments.results.columns.date'),
        className: 'hidden whitespace-nowrap text-sm text-muted-foreground tabular-nums sm:table-cell',
        headerClassName: 'hidden sm:table-cell',
        cell: (r) => formatDate(r.takenAt, 'd MMM yyyy'),
      },
      {
        key: 'score',
        header: kind === 'COGNITIVE' ? t('assessments.results.cognitiveIndex') : kind === 'CAREER' ? t('assessments.results.topCodes') : t('assessments.results.columns.score'),
        cell: (r) => <ScoreCell row={r} scale={scale} kind={kind} />,
      },
      {
        key: 'band',
        header: t('assessments.results.columns.band'),
        cell: (r) => <BandBadge band={r.scales.find((s) => s.key === scale?.key)?.band ?? r.scales[0]?.band ?? null} size="sm" />,
      },
      {
        key: 'origin',
        header: t('assessments.results.columns.origin'),
        className: 'hidden text-xs text-muted-foreground lg:table-cell',
        headerClassName: 'hidden lg:table-cell',
        cell: (r) => t(`assessments.results.origin.${r.origin}`),
      },
    ],
    [t, formatDate, scale, kind],
  );
  return (
    <DataTable
      columns={columns}
      rows={visible}
      rowKey={(r) => r.id}
      pagination={total > PAGE_SIZE ? { page: Math.min(page, totalPages), limit: PAGE_SIZE, total, totalPages } : undefined}
      onPageChange={setPage}
      loading={loading}
      skeletonRows={6}
      emptyTitle={t('assessments.results.empty')}
      emptyDescription={t('assessments.results.emptyHint')}
    />
  );
}
