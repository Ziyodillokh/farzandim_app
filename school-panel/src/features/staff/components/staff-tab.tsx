'use client';

import { useMemo, useState } from 'react';

import { useCan, useSession } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { DataTable, type SortState } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { ROLES } from '@/auth/permissions';
import { Card } from '@/components/ui/card';
import type { RoleKey } from '@/data/contracts';
import type { StaffRow } from '@/data/mock/services/staff';
import { useI18n } from '@/i18n';
import { accountMenu, isProtectedRole } from '../account';
import { type StaffFilter, useRemoveStaffAccount, useSetStaffActive, useStaffList } from '../hooks';
import { StaffAccountDialog } from './staff-account-dialog';
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
  const [accountFor, setAccountFor] = useState<StaffRow | null>(null);
  const [removingAccount, setRemovingAccount] = useState<StaffRow | null>(null);
  const removeAccount = useRemoveStaffAccount();
  const staff = useStaffList(filter);
  const setActive = useSetStaffActive();
  const activate = setActive.mutate;
  const canManage = can('staff.manage');

  const update = (patch: Partial<StaffFilter>) => setFilter((f) => ({ ...f, page: 1, ...patch }));

  const selfId = session?.staffId ?? null;
  const actions = useMemo<StaffActions>(
    () => ({
      canManage,
      selfId,
      onEdit: setEditing,
      onToggleActive: (row) => (row.active ? setDeactivating(row) : activate({ id: row.id, active: true })),
      // Menyu bandi nofaol bo'lsa ham qayta tekshiriladi: o'z qatori uchun oyna ochilmaydi (server — 409 'self').
      onAccount: (row) => {
        if (accountMenu(row, selfId).canSet) setAccountFor(row);
      },
      onRemoveAccount: (row) => {
        if (accountMenu(row, selfId).canRemove) setRemovingAccount(row);
      },
    }),
    [canManage, selfId, activate],
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
        <Card>
          <ErrorState error={staff.error} onRetry={() => void staff.refetch()} />
        </Card>
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
      <StaffAccountDialog row={accountFor} onOpenChange={(open) => !open && setAccountFor(null)} />
      <ConfirmDialog
        open={Boolean(removingAccount)}
        onOpenChange={(open) => !open && setRemovingAccount(null)}
        title={t('staff.account.remove')}
        description={t(removingAccount && isProtectedRole(removingAccount.role) ? 'staff.account.removeConfirmProtected' : 'staff.account.removeConfirm', {
          name: removingAccount?.fullName ?? '',
        })}
        confirmLabel={t('staff.account.remove')}
        destructive
        loading={removeAccount.isPending}
        onConfirm={() => {
          if (!removingAccount) return;
          removeAccount.mutate(removingAccount.id, { onSettled: () => setRemovingAccount(null) });
        }}
      />
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
