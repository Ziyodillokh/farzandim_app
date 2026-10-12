'use client';

import { Plus, ShieldOff } from 'lucide-react';
import { useState } from 'react';

import { Can } from '@/auth/can';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { DataTable, type Column } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { SearchInput, Toolbar } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { ExceptionRow, ExceptionStatus } from '@/data/mock/services/school-mode';
import { ExceptionDialog } from '@/features/school-mode/components/exception-dialog';
import { SafetyCallout } from '@/features/school-mode/components/safety-callout';
import { useRevokeException, useSmExceptions } from '@/features/school-mode/hooks';
import { useI18n } from '@/i18n';

const TABS: readonly ExceptionStatus[] = ['ACTIVE', 'SCHEDULED', 'EXPIRED', 'REVOKED'];
/** Faol va hali boshlanmagan istisnolarni bekor qilish mumkin. */
const REVOCABLE: ReadonlySet<ExceptionStatus> = new Set(['ACTIVE', 'SCHEDULED']);

export default function SchoolModeExceptionsPage() {
  const { t, formatDate } = useI18n();
  const [status, setStatus] = useState<ExceptionStatus>('ACTIVE');
  const [search, setSearch] = useState('');
  const [createOpen, setCreateOpen] = useState(false);
  const [revoking, setRevoking] = useState<ExceptionRow | null>(null);
  const list = useSmExceptions({ status, search });
  const revoke = useRevokeException();

  const period = (r: ExceptionRow) => `${formatDate(r.from, 'dd.MM · HH:mm')} – ${formatDate(r.until, 'HH:mm')}`;

  const columns: Column<ExceptionRow>[] = [
    { key: 'student', header: t('schoolMode.exceptions.columns.student'), cell: (r) => <span className="font-medium">{r.studentName}</span> },
    { key: 'class', header: t('schoolMode.exceptions.columns.class'), cell: (r) => <Badge variant="outline">{r.className}</Badge> },
    {
      key: 'period',
      header: t('schoolMode.exceptions.columns.period'),
      className: 'whitespace-nowrap tabular-nums',
      cell: (r) => (
        <div>
          <p>{period(r)}</p>
          {r.revokedAt && <p className="text-xs text-destructive">{t('schoolMode.exceptions.revokedAt', { time: formatDate(r.revokedAt, 'HH:mm') })}</p>}
        </div>
      ),
    },
    {
      key: 'reason',
      header: t('schoolMode.exceptions.columns.reason'),
      cell: (r) => (
        <p className="line-clamp-2 max-w-sm text-sm text-muted-foreground" title={r.reason}>
          {r.reason}
        </p>
      ),
    },
    { key: 'by', header: t('schoolMode.exceptions.columns.issuedBy'), className: 'text-sm', cell: (r) => r.byName },
    {
      key: 'actions',
      header: <span className="sr-only">{t('common.actions')}</span>,
      className: 'text-right',
      cell: (r) =>
        REVOCABLE.has(r.status) ? (
          <Can perm="schoolMode.exception">
            <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive" onClick={() => setRevoking(r)}>
              <ShieldOff />
              {t('schoolMode.exceptions.revoke')}
            </Button>
          </Can>
        ) : null,
    },
  ];

  const counts = list.data?.counts;

  return (
    <>
      <PageHeader
        title={t('schoolMode.exceptions.title')}
        subtitle={t('schoolMode.exceptions.subtitle')}
        actions={
          <Can perm="schoolMode.exception">
            <Button onClick={() => setCreateOpen(true)}>
              <Plus />
              {t('schoolMode.exceptions.add')}
            </Button>
          </Can>
        }
      />

      <Toolbar className="justify-between">
        <Tabs value={status} onValueChange={(v) => setStatus(v as ExceptionStatus)} className="max-w-full overflow-x-auto">
          <TabsList>
            {TABS.map((s) => (
              <TabsTrigger key={s} value={s}>
                {t(`schoolMode.exceptions.tabs.${s}`)}
                {counts && (
                  <Badge variant={s === 'ACTIVE' && counts[s] > 0 ? 'default' : 'secondary'} size="sm" className="tabular-nums">
                    {counts[s]}
                  </Badge>
                )}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
        <SearchInput value={search} onChange={setSearch} placeholder={t('schoolMode.exceptions.searchPlaceholder')} />
      </Toolbar>

      {list.isError ? (
        <ErrorState error={list.error} onRetry={() => void list.refetch()} />
      ) : (
        <DataTable
          columns={columns}
          rows={list.data?.items}
          rowKey={(r) => r.id}
          loading={list.isLoading}
          skeletonRows={4}
          emptyTitle={t(`schoolMode.exceptions.empty.${status}`)}
          emptyDescription={t('schoolMode.exceptions.emptyHint')}
        />
      )}

      <SafetyCallout className="mt-6" />

      <ExceptionDialog open={createOpen} onOpenChange={setCreateOpen} />
      <ConfirmDialog
        open={Boolean(revoking)}
        onOpenChange={(open) => !open && setRevoking(null)}
        title={t('schoolMode.exceptions.revokeTitle')}
        description={t('schoolMode.exceptions.revokeDescription', { name: revoking?.studentName ?? '' })}
        confirmLabel={t('schoolMode.exceptions.revoke')}
        destructive
        loading={revoke.isPending}
        onConfirm={() => revoking && revoke.mutate(revoking.id, { onSuccess: () => setRevoking(null) })}
      />
    </>
  );
}
