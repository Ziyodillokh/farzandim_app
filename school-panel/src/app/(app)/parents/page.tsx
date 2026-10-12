'use client';

import { Send, ShieldCheck } from 'lucide-react';
import { useCallback, useMemo, useState } from 'react';
import { toast } from 'sonner';

import { Can } from '@/auth/can';
import { useCan } from '@/auth/use-session';
import { DataTable, type SortState } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { ExportMenu } from '@/components/common/export-menu';
import { PageHeader } from '@/components/common/page-header';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Button } from '@/components/ui/button';
import type { Guardian, ParentLinkStatus } from '@/data/contracts';
import { BulkInviteDialog } from '@/features/parents/components/bulk-invite-dialog';
import { InviteQrDialog } from '@/features/parents/components/invite-qr-dialog';
import { ParentsStats } from '@/features/parents/components/parents-stats';
import { type GuardianActions, useGuardianColumns } from '@/features/parents/components/use-guardian-columns';
import {
  fetchAllGuardians,
  type GuardianFilter,
  type GuardianRow,
  useGuardians,
  useInvite,
  useResend,
  useSimulateLink,
} from '@/features/parents/hooks';
import { useClassOptions } from '@/features/students/hooks';
import { useI18n } from '@/i18n';
import { downloadCsv } from '@/lib/csv';
import { errorKey } from '@/lib/errors';

const STATUSES: ParentLinkStatus[] = ['LINKED', 'INVITED', 'NOT_INVITED'];

export default function ParentsPage() {
  const { t, formatDate } = useI18n();
  const can = useCan();
  const [filter, setFilter] = useState<GuardianFilter>({ page: 1, limit: 20, sortBy: 'name', sortDir: 'asc' });
  const [shown, setShown] = useState<Guardian | null>(null);
  const [bulkOpen, setBulkOpen] = useState(false);
  const guardians = useGuardians(filter);
  const classes = useClassOptions();
  const invite = useInvite();
  const resend = useResend();
  const simulate = useSimulateLink();

  const update = (patch: Partial<GuardianFilter>) => setFilter((f) => ({ ...f, page: 1, ...patch }));
  const simulateLink = simulate.mutate;
  const busyId = [invite, resend, simulate].find((m) => m.isPending)?.variables ?? null;

  const runInvite = useCallback(
    async (row: GuardianRow, fn: (id: string) => Promise<Guardian>) => {
      try {
        setShown(await fn(row.id));
      } catch {
        // toast — hooks ichida
      }
    },
    [],
  );

  const actions = useMemo<GuardianActions>(
    () => ({
      canLink: can('guardians.link'),
      busyId,
      onInvite: (row) => void runInvite(row, invite.mutateAsync),
      onResend: (row) => void runInvite(row, resend.mutateAsync),
      onShowCode: (row) => setShown(row),
      onSimulate: (row) => simulateLink(row.id),
    }),
    [can, busyId, runInvite, invite.mutateAsync, resend.mutateAsync, simulateLink],
  );
  const columns = useGuardianColumns(actions);

  const exportCsv = async () => {
    try {
      const rows = await fetchAllGuardians({ ...filter, page: 1 });
      downloadCsv(t('parents.exportFile'), rows, [
        { header: t('common.fullName'), value: (r) => r.fullName },
        { header: t('parents.csv.relation'), value: (r) => t(`enums.relation.${r.relation}`) },
        { header: t('common.phone'), value: (r) => r.phone },
        { header: t('parents.columns.children'), value: (r) => r.children.map((c) => c.name).join(', ') },
        { header: t('parents.csv.classes'), value: (r) => [...new Set(r.children.map((c) => c.className))].join(', ') },
        { header: t('parents.columns.status'), value: (r) => t(`enums.linkStatus.${r.linkStatus}`) },
        { header: t('parents.csv.code'), value: (r) => r.inviteCode },
        { header: t('parents.csv.expires'), value: (r) => (r.inviteExpiresAt ? formatDate(r.inviteExpiresAt, 'yyyy-MM-dd') : '') },
        { header: t('parents.csv.linkedAt'), value: (r) => (r.linkedAt ? formatDate(r.linkedAt, 'yyyy-MM-dd') : '') },
      ]);
    } catch (error) {
      toast.error(t(errorKey(error)));
    }
  };

  const selectedClass = classes.data?.find((c) => c.id === filter.classId);

  return (
    <>
      <PageHeader
        title={t('parents.title')}
        subtitle={t('parents.subtitle')}
        actions={
          <>
            <ExportMenu onCsv={() => void exportCsv()} />
            <Can perm="guardians.link">
              <Button onClick={() => setBulkOpen(true)}>
                <Send />
                {t('parents.bulk.button')}
              </Button>
            </Can>
          </>
        }
      />

      <ParentsStats />

      <p className="mb-4 flex items-start gap-2 rounded-xl border border-primary/20 bg-primary/5 px-4 py-3 text-sm text-muted-foreground">
        <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
        {t('parents.privacy')}
      </p>

      <Toolbar>
        <SearchInput value={filter.search ?? ''} onChange={(search) => update({ search })} placeholder={t('parents.searchPlaceholder')} />
        <FilterSelect
          value={filter.classId}
          onChange={(classId) => update({ classId })}
          options={(classes.data ?? []).map((c) => ({ value: c.id, label: c.name }))}
          allLabel={`${t('parents.filters.class')}: ${t('common.all')}`}
          className="sm:w-40"
        />
        <FilterSelect
          value={filter.linkStatus}
          onChange={(v) => update({ linkStatus: v as ParentLinkStatus | undefined })}
          options={STATUSES.map((s) => ({ value: s, label: t(`enums.linkStatus.${s}`) }))}
          allLabel={`${t('parents.filters.status')}: ${t('common.all')}`}
          className="sm:w-56"
        />
      </Toolbar>

      {guardians.isError ? (
        <div className="rounded-xl border bg-card">
          <ErrorState error={guardians.error} onRetry={() => void guardians.refetch()} />
        </div>
      ) : (
        <DataTable
          columns={columns}
          rows={guardians.data?.items}
          rowKey={(r) => r.id}
          loading={guardians.isLoading}
          pagination={guardians.data?.pagination}
          onPageChange={(page) => setFilter((f) => ({ ...f, page }))}
          sort={{ sortBy: filter.sortBy, sortDir: filter.sortDir }}
          onSortChange={(sort: SortState) => setFilter((f) => ({ ...f, ...sort, page: 1 }))}
          emptyTitle={t('parents.empty')}
        />
      )}

      <InviteQrDialog guardian={shown} onOpenChange={(open) => !open && setShown(null)} />
      <BulkInviteDialog
        open={bulkOpen}
        onOpenChange={setBulkOpen}
        classId={filter.classId}
        className={selectedClass?.name}
        search={filter.search}
      />
    </>
  );
}
