'use client';

import { History } from 'lucide-react';
import { useMemo, useState } from 'react';

import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { PageHeader } from '@/components/common/page-header';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { paginate } from '@/data/mock/query';
import { CorrectionsTable } from '@/features/attendance/components/corrections-table';
import { useAttendanceClassOptions, useCorrections } from '@/features/attendance/hooks';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';
import { matchesSearch } from '@/lib/normalize-search';

const PAGE_SIZE = 20;

export default function CorrectionsPage() {
  const { t, formatNumber } = useI18n();
  const query = useCorrections();
  const classes = useAttendanceClassOptions();
  const [search, setSearch] = useState('');
  const [classId, setClassId] = useState<string>();
  const [page, setPage] = useState(1);

  const filtered = useMemo(
    () =>
      (query.data ?? []).filter(
        (r) =>
          (!classId || r.record.classId === classId) &&
          matchesSearch(`${r.studentName} ${r.correction.reason} ${r.byName}`, search),
      ),
    [query.data, classId, search],
  );
  const paged = query.data ? paginate(filtered, page, PAGE_SIZE) : undefined;
  const classOptions = (classes.data ?? []).map((c) => ({ value: c.id, label: c.name }));

  const exportCsv = () =>
    downloadCsv(t('attendance.corrections.exportFile'), filtered, [
      { header: t('attendance.corrections.columns.at'), value: (r) => r.correction.at },
      { header: t('attendance.corrections.columns.student'), value: (r) => r.studentName },
      { header: t('common.class'), value: (r) => r.className },
      { header: t('attendance.corrections.columns.day'), value: (r) => r.record.date },
      { header: t('common.from'), value: (r) => t(`enums.attendanceStatus.${r.correction.from}`) },
      { header: t('common.to'), value: (r) => t(`enums.attendanceStatus.${r.correction.to}`) },
      { header: t('attendance.corrections.columns.reason'), value: (r) => r.correction.reason },
      { header: t('attendance.corrections.columns.by'), value: (r) => r.byName },
    ]);

  return (
    <>
      <PageHeader
        title={t('attendance.corrections.title')}
        subtitle={t('attendance.corrections.subtitle')}
        badge={
          query.data && (
            <span className="inline-flex items-center gap-1.5 rounded-full bg-primary/10 px-2.5 py-1 text-xs font-semibold text-primary">
              <History className="h-3.5 w-3.5" />
              {t('attendance.corrections.total')}: {formatNumber(query.data.length)}
            </span>
          )
        }
        actions={<ExportMenu onCsv={exportCsv} disabled={!query.data} />}
      />
      <Toolbar>
        <SearchInput
          value={search}
          onChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          placeholder={t('attendance.corrections.searchPlaceholder')}
        />
        {classOptions.length > 1 && (
          <FilterSelect
            value={classId}
            onChange={(v) => {
              setClassId(v);
              setPage(1);
            }}
            options={classOptions}
            allLabel={`${t('common.class')}: ${t('common.all')}`}
            className="sm:w-40"
          />
        )}
      </Toolbar>
      {query.error ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : (
        <CorrectionsTable rows={paged?.items} loading={query.isLoading} pagination={paged?.pagination} onPageChange={setPage} />
      )}
    </>
  );
}
