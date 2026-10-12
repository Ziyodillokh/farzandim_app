'use client';

import { ChevronRight, FilterX } from 'lucide-react';
import { useMemo, useState } from 'react';
import { toast } from 'sonner';

import { DataTable, type Column, type SortState } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { PageHeader } from '@/components/common/page-header';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { api } from '@/data/api';
import type { AuditLog, AuditModule } from '@/data/contracts';
import type { AuditFilter } from '@/data/mock/services/staff';
import { AuditDetailSheet } from '@/features/audit/components/audit-detail-sheet';
import { useAuditActors, useAuditLog } from '@/features/audit/hooks';
import { useI18n } from '@/i18n';
import { enums } from '@/i18n/uz/enums';
import { downloadCsv } from '@/lib/csv';
import { errorKey } from '@/lib/errors';
import { initials } from '@/lib/utils';

const MODULES = Object.keys(enums.auditModule) as AuditModule[];
const INITIAL: AuditFilter = { page: 1, limit: 25, sortBy: 'at', sortDir: 'desc' };

export default function AuditPage() {
  const { t, formatDate } = useI18n();
  const [filter, setFilter] = useState<AuditFilter>(INITIAL);
  const [selected, setSelected] = useState<AuditLog | null>(null);
  const log = useAuditLog(filter);
  const actors = useAuditActors();

  const update = (patch: Partial<AuditFilter>) => setFilter((f) => ({ ...f, page: 1, ...patch }));
  const filtered = Boolean(filter.search || filter.module || filter.actorId || filter.from || filter.to);

  const columns = useMemo<Column<AuditLog>[]>(
    () => [
      {
        key: 'at',
        header: t('audit.columns.at'),
        sortKey: 'at',
        className: 'whitespace-nowrap',
        cell: (r) => (
          <div>
            <p className="font-medium tabular-nums">{formatDate(r.at, 'HH:mm')}</p>
            <p className="text-xs text-muted-foreground">{formatDate(r.at, 'd MMM yyyy')}</p>
          </div>
        ),
      },
      {
        key: 'actor',
        header: t('audit.columns.actor'),
        sortKey: 'actor',
        cell: (r) => (
          <div className="flex items-center gap-2.5">
            <Avatar className="h-8 w-8">
              <AvatarFallback className="bg-primary/10 text-2xs font-semibold text-primary">{initials(r.actorName)}</AvatarFallback>
            </Avatar>
            <span className="max-w-[180px] truncate">{r.actorName}</span>
          </div>
        ),
      },
      { key: 'module', header: t('audit.columns.module'), sortKey: 'module', cell: (r) => <Badge variant="outline">{t(`enums.auditModule.${r.module}`)}</Badge> },
      {
        key: 'summary',
        header: t('audit.columns.summary'),
        cell: (r) => (
          <div className="min-w-0 max-w-xl">
            <p className="line-clamp-2">{r.summary}</p>
            <code className="text-2xs text-muted-foreground">{r.action}</code>
          </div>
        ),
      },
      { key: 'open', header: '', className: 'w-10 text-muted-foreground', cell: () => <ChevronRight className="h-4 w-4" /> },
    ],
    [t, formatDate],
  );

  const exportCsv = async () => {
    try {
      const rows = await api.audit.exportRows(filter);
      downloadCsv(t('audit.exportFile'), rows, [
        { header: t('audit.columns.at'), value: (r) => formatDate(r.at, 'yyyy-MM-dd HH:mm:ss') },
        { header: t('audit.columns.actor'), value: (r) => r.actorName },
        { header: t('audit.columns.module'), value: (r) => t(`enums.auditModule.${r.module}`) },
        { header: t('audit.csv.action'), value: (r) => r.action },
        { header: t('audit.columns.summary'), value: (r) => r.summary },
        { header: t('audit.csv.entity'), value: (r) => r.entityId },
        { header: t('audit.csv.before'), value: (r) => (r.before === null ? '' : JSON.stringify(r.before)) },
        { header: t('audit.csv.after'), value: (r) => (r.after === null ? '' : JSON.stringify(r.after)) },
      ]);
    } catch (error) {
      toast.error(t(errorKey(error)));
    }
  };

  return (
    <>
      <PageHeader title={t('audit.title')} subtitle={t('audit.subtitle')} actions={<ExportMenu onCsv={() => void exportCsv()} />} />

      <Toolbar>
        <SearchInput value={filter.search ?? ''} onChange={(search) => update({ search })} placeholder={t('audit.searchPlaceholder')} />
        <FilterSelect
          value={filter.module}
          onChange={(v) => update({ module: v as AuditModule | undefined })}
          options={MODULES.map((m) => ({ value: m, label: t(`enums.auditModule.${m}`) }))}
          allLabel={`${t('audit.filters.module')}: ${t('common.all')}`}
        />
        <FilterSelect
          value={filter.actorId}
          onChange={(actorId) => update({ actorId })}
          options={(actors.data ?? []).map((a) => ({ value: a.id, label: a.name }))}
          allLabel={`${t('audit.filters.actor')}: ${t('common.all')}`}
          className="sm:w-56"
        />
        <Input
          type="date"
          value={filter.from ?? ''}
          max={filter.to}
          onChange={(e) => update({ from: e.target.value || undefined })}
          aria-label={t('audit.filters.from')}
          title={t('audit.filters.from')}
          className="w-full sm:w-40"
        />
        <Input
          type="date"
          value={filter.to ?? ''}
          min={filter.from}
          onChange={(e) => update({ to: e.target.value || undefined })}
          aria-label={t('audit.filters.to')}
          title={t('audit.filters.to')}
          className="w-full sm:w-40"
        />
        {filtered && (
          <Button variant="ghost" onClick={() => setFilter(INITIAL)}>
            <FilterX />
            {t('audit.filters.reset')}
          </Button>
        )}
      </Toolbar>

      {log.isError ? (
        <div className="rounded-xl border bg-card">
          <ErrorState error={log.error} onRetry={() => void log.refetch()} />
        </div>
      ) : (
        <DataTable
          columns={columns}
          rows={log.data?.items}
          rowKey={(r) => r.id}
          loading={log.isLoading}
          pagination={log.data?.pagination}
          onPageChange={(page) => setFilter((f) => ({ ...f, page }))}
          sort={{ sortBy: filter.sortBy, sortDir: filter.sortDir }}
          onSortChange={(sort: SortState) => setFilter((f) => ({ ...f, ...sort, page: 1 }))}
          onRowClick={setSelected}
          emptyTitle={t('audit.empty')}
        />
      )}
      <p className="mt-3 text-xs text-muted-foreground">{t('audit.retention')}</p>

      <AuditDetailSheet entry={selected} onOpenChange={(open) => !open && setSelected(null)} />
    </>
  );
}
