'use client';

import { BellRing } from 'lucide-react';
import { useMemo, useState } from 'react';
import { toast } from 'sonner';

import { DataTable, type Column, type SortState } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { DeviceModeBadge } from '@/components/common/status-badges';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { api } from '@/data/api';
import type { DeviceModeStatus, DeviceOs } from '@/data/contracts';
import type { DeviceFilter, DeviceRow } from '@/data/mock/services/school-mode';
import { DeviceIcon } from '@/features/students/components/device-icon';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';
import { useRemindParents, useSmDevices } from '../hooks';
import { smErrorKey } from '../lib';

const STATUSES: readonly DeviceModeStatus[] = ['NO_PERMISSION', 'OFFLINE', 'APPLIED', 'NO_PHONE'];
const OSES: readonly DeviceOs[] = ['IOS', 'ANDROID', 'NONE'];
const EXPORT_LIMIT = 500;

async function fetchAll(filter: DeviceFilter): Promise<DeviceRow[]> {
  const first = await api.schoolMode.devices({ ...filter, page: 1, limit: EXPORT_LIMIT });
  const rest = await Promise.all(
    Array.from({ length: first.pagination.totalPages - 1 }, (_, i) => api.schoolMode.devices({ ...filter, page: i + 2, limit: EXPORT_LIMIT })),
  );
  return [...first.items, ...rest.flatMap((p) => p.items)];
}

/** Qurilmalar jadvali: filtrlar, NO_PERMISSION qatorlarini tanlab ota-onaga eslatma, CSV. */
export function DevicesPanel({
  filter,
  onFilterChange,
  classOptions,
}: {
  filter: DeviceFilter;
  onFilterChange: (next: DeviceFilter) => void;
  classOptions: Array<{ value: string; label: string }>;
}) {
  const { t, formatRelative } = useI18n();
  const devices = useSmDevices(filter);
  const remind = useRemindParents();
  const [selected, setSelected] = useState<ReadonlySet<string>>(new Set());
  const [remindingAll, setRemindingAll] = useState(false);

  const update = (patch: Partial<DeviceFilter>) => {
    setSelected(new Set());
    onFilterChange({ ...filter, page: 1, ...patch });
  };
  const pageEligible = useMemo(() => (devices.data?.items ?? []).filter((r) => r.status === 'NO_PERMISSION').map((r) => r.studentId), [devices.data]);
  const allPageSelected = pageEligible.length > 0 && pageEligible.every((id) => selected.has(id));

  const toggle = (id: string, on: boolean) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (on) next.add(id);
      else next.delete(id);
      return next;
    });
  const togglePage = (on: boolean) =>
    setSelected((prev) => {
      const next = new Set(prev);
      for (const id of pageEligible) {
        if (on) next.add(id);
        else next.delete(id);
      }
      return next;
    });

  const sendSelected = () => remind.mutate([...selected], { onSuccess: () => setSelected(new Set()) });
  const sendAll = async () => {
    setRemindingAll(true);
    try {
      const rows = await fetchAll({ classId: filter.classId, status: 'NO_PERMISSION' });
      if (rows.length === 0) {
        toast.info(t('schoolMode.devices.remindNone'));
        setRemindingAll(false);
        return;
      }
      remind.mutate(
        rows.map((r) => r.studentId),
        { onSettled: () => setRemindingAll(false) },
      );
    } catch (error) {
      toast.error(t(smErrorKey(error)));
      setRemindingAll(false);
    }
  };

  const exportCsv = async () => {
    const rows = await fetchAll(filter).catch((error: unknown) => {
      toast.error(t(smErrorKey(error)));
      return null;
    });
    if (!rows) return;
    downloadCsv(t('schoolMode.devices.exportFile'), rows, [
      { header: t('schoolMode.devices.columns.student'), value: (r) => r.studentName },
      { header: t('students.code'), value: (r) => r.studentCode },
      { header: t('schoolMode.devices.columns.class'), value: (r) => r.className },
      { header: t('schoolMode.devices.columns.os'), value: (r) => t(`enums.device.${r.os}`) },
      { header: t('schoolMode.devices.columns.status'), value: (r) => t(`enums.deviceModeStatus.${r.status}`) },
      { header: t('schoolMode.devices.columns.lastSeen'), value: (r) => r.lastSeenAt ?? '' },
    ]);
  };

  const columns: Column<DeviceRow>[] = [
    {
      key: 'select',
      headerClassName: 'w-10',
      header: (
        <Checkbox
          checked={allPageSelected}
          disabled={pageEligible.length === 0}
          onCheckedChange={(v) => togglePage(v === true)}
          aria-label={t('schoolMode.devices.selectPage')}
        />
      ),
      cell: (r) => (
        <Checkbox
          checked={selected.has(r.studentId)}
          disabled={r.status !== 'NO_PERMISSION'}
          onCheckedChange={(v) => toggle(r.studentId, v === true)}
          aria-label={r.studentName}
          title={r.status !== 'NO_PERMISSION' ? t('schoolMode.devices.remindHint') : undefined}
        />
      ),
    },
    {
      key: 'student',
      header: t('schoolMode.devices.columns.student'),
      sortKey: 'name',
      cell: (r) => (
        <div className="min-w-0">
          <p className="truncate font-medium">
            {r.studentName}
            {r.hasException && (
              <Badge variant="info" size="sm" className="ml-2">
                {t('schoolMode.devices.exceptionBadge')}
              </Badge>
            )}
          </p>
          <p className="text-xs text-muted-foreground">{r.studentCode}</p>
        </div>
      ),
    },
    {
      key: 'class',
      header: t('schoolMode.devices.columns.class'),
      sortKey: 'class',
      cell: (r) => (
        <Badge variant="outline" className="whitespace-nowrap">
          {r.className}
        </Badge>
      ),
    },
    { key: 'os', header: t('schoolMode.devices.columns.os'), cell: (r) => <DeviceIcon device={r.os} /> },
    { key: 'status', header: t('schoolMode.devices.columns.status'), sortKey: 'status', cell: (r) => <DeviceModeBadge status={r.status} /> },
    {
      key: 'lastSeen',
      header: t('schoolMode.devices.columns.lastSeen'),
      sortKey: 'lastSeen',
      className: 'whitespace-nowrap text-sm text-muted-foreground',
      cell: (r) => (r.lastSeenAt ? formatRelative(r.lastSeenAt) : t('schoolMode.devices.never')),
    },
  ];

  return (
    <>
      <Toolbar>
        <SearchInput value={filter.search ?? ''} onChange={(search) => update({ search })} placeholder={t('schoolMode.devices.searchPlaceholder')} />
        <FilterSelect
          value={filter.status}
          onChange={(v) => update({ status: v as DeviceModeStatus | undefined })}
          options={STATUSES.map((s) => ({ value: s, label: t(`enums.deviceModeStatus.${s}`) }))}
          allLabel={`${t('schoolMode.devices.filters.status')}: ${t('common.all')}`}
          className="sm:w-48"
        />
        <FilterSelect
          value={filter.os}
          onChange={(v) => update({ os: v as DeviceOs | undefined })}
          options={OSES.map((o) => ({ value: o, label: t(`enums.device.${o}`) }))}
          allLabel={`${t('schoolMode.devices.filters.os')}: ${t('common.all')}`}
          className="sm:w-48"
        />
        {classOptions.length > 1 && (
          <FilterSelect
            value={filter.classId}
            onChange={(classId) => update({ classId })}
            options={classOptions}
            allLabel={`${t('schoolMode.devices.filters.class')}: ${t('common.all')}`}
            className="sm:w-40"
          />
        )}
        <div className="ml-auto flex flex-wrap items-center gap-2">
          {selected.size > 0 ? (
            <Button onClick={sendSelected} loading={remind.isPending && !remindingAll}>
              <BellRing />
              {t('schoolMode.devices.remindSelected', { count: selected.size })}
            </Button>
          ) : (
            <Button variant="soft" onClick={() => void sendAll()} loading={remindingAll}>
              <BellRing />
              {t('schoolMode.devices.remindAll')}
            </Button>
          )}
          <ExportMenu onCsv={() => void exportCsv()} />
        </div>
      </Toolbar>
      {devices.isError ? (
        <ErrorState error={devices.error} onRetry={() => void devices.refetch()} />
      ) : (
      <DataTable
        columns={columns}
        rows={devices.data?.items}
        rowKey={(r) => r.studentId}
        loading={devices.isLoading}
        pagination={devices.data?.pagination}
        onPageChange={(page) => onFilterChange({ ...filter, page })}
        sort={{ sortBy: filter.sortBy, sortDir: filter.sortDir }}
        onSortChange={(sort: SortState) => onFilterChange({ ...filter, ...sort, page: 1 })}
      />
      )}
    </>
  );
}
