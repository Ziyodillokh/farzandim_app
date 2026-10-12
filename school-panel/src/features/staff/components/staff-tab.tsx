'use client';

import { useMemo, useState } from 'react';

import { useCan, useSession } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { DataTable, type SortState } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { ROLES } from '@/auth/permissions';
import type { RoleKey } from '@/data/contracts';
import type { StaffRow } from '@/data/mock/services/staff';
import { useI18n } from '@/i18n';
import { type StaffFilter, useSetStaffActive, useStaffList } from '../hooks';
import { StaffFormDialog } from './staff-form-dialog';
import { type StaffActions, useStaffColumns } from './use-staff-columns';

const ROLE_KEYS = Object.keys(ROLES) as RoleKey[];
const ACTIVE = 'active';
const INACTIVE = 'inactive';

export function StaffTab({ createOpen, onCreateOpenChange }: { createOpen: boolean; onCreateOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const can = useCan();
  const session = useSession();
  const [filter, setFilter] = useState<StaffFilter>({ page: 1, limit: 20, sortBy: 'name', sortDir: 'asc' });
  const [editing, setEditing] = useState<StaffRow | null>(null);
  const [deactivating, setDeactivating] = useState<StaffRow | null>(null);
  const staff = useStaffList(filter);
  const setActive = useSetStaffActive();
  const activate = setActive.mutate;
  const canManage = can('staff.manage');

  const update = (patch: Partial<StaffFilter>) => setFilter((f) => ({ ...f, page: 1, ...patch }));

  const actions = useMemo<StaffActions>(
    () => ({
      canManage,
      selfId: session?.staffId ?? null,
      onEdit: setEditing,
      onToggleActive: (row) => (row.active ? setDeactivating(row) : activate({ id: row.id, active: true })),
    }),
    [canManage, session?.staffId, activate],
  );
  const columns = useStaffColumns(actions);

  const confirmDeactivate = async () => {
    if (!deactivating) return;
    try {
      await setActive.mutateAsync({ id: deactivating.id, active: false });
      setDeactivating(null);
    } catch {
      // toast — hooks ichida
    }
  };

  const activeValue = filter.active === undefined ? undefined : filter.active ? ACTIVE : INACTIVE;

  return (
    <>
      <Toolbar>
        <SearchInput value={filter.search ?? ''} onChange={(search) => update({ search })} placeholder={t('staff.searchPlaceholder')} />
        <FilterSelect
          value={filter.role}
          onChange={(v) => update({ role: v as RoleKey | undefined })}
          options={ROLE_KEYS.map((r) => ({ value: r, label: t(`enums.role.${r}`) }))}
          allLabel={`${t('staff.filters.role')}: ${t('common.all')}`}
        />
        <FilterSelect
          value={activeValue}
          onChange={(v) => update({ active: v === undefined ? undefined : v === ACTIVE })}
          options={[
            { value: ACTIVE, label: t('staff.status.active') },
            { value: INACTIVE, label: t('staff.status.inactive') },
          ]}
          allLabel={`${t('staff.filters.status')}: ${t('common.all')}`}
          className="sm:w-44"
        />
      </Toolbar>

      {staff.isError ? (
        <div className="rounded-xl border bg-card">
          <ErrorState error={staff.error} onRetry={() => void staff.refetch()} />
        </div>
      ) : (
        <DataTable
          columns={columns}
          rows={staff.data?.items}
          rowKey={(r) => r.id}
          loading={staff.isLoading}
          pagination={staff.data?.pagination}
          onPageChange={(page) => setFilter((f) => ({ ...f, page }))}
          sort={{ sortBy: filter.sortBy, sortDir: filter.sortDir }}
          onSortChange={(sort: SortState) => setFilter((f) => ({ ...f, ...sort, page: 1 }))}
          onRowClick={canManage ? setEditing : undefined}
        />
      )}

      <StaffFormDialog open={createOpen} onOpenChange={onCreateOpenChange} />
      <StaffFormDialog open={Boolean(editing)} onOpenChange={(open) => !open && setEditing(null)} row={editing ?? undefined} />
      <ConfirmDialog
        open={Boolean(deactivating)}
        onOpenChange={(open) => !open && setDeactivating(null)}
        title={t('staff.deactivate.title')}
        description={t('staff.deactivate.text', { name: deactivating?.fullName ?? '' })}
        confirmLabel={t('staff.actions.deactivate')}
        destructive
        loading={setActive.isPending}
        onConfirm={() => void confirmDeactivate()}
      />
    </>
  );
}
