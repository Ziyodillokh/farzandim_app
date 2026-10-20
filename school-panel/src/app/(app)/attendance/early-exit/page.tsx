'use client';

import { Plus } from 'lucide-react';
import { useCallback, useState } from 'react';

import { Can } from '@/auth/can';
import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { EarlyExitDialog } from '@/features/attendance/components/early-exit-dialog';
import { EarlyExitTable, type EarlyExitRow } from '@/features/attendance/components/early-exit-table';
import { useDecideEarlyExit, useEarlyExits } from '@/features/attendance/hooks';
import { useI18n } from '@/i18n';

type Decision = { row: EarlyExitRow; approve: boolean };

export default function EarlyExitPage() {
  const { t, formatNumber } = useI18n();
  const can = useCan();
  const [tab, setTab] = useState<'pending' | 'all'>('pending');
  const [createOpen, setCreateOpen] = useState(false);
  const [decision, setDecision] = useState<Decision | null>(null);
  const pending = useEarlyExits('PENDING');
  const all = useEarlyExits();
  const decide = useDecideEarlyExit();
  const list = tab === 'pending' ? pending : all;
  const onDecide = useCallback((row: EarlyExitRow, approve: boolean) => setDecision({ row, approve }), []);
  const pendingCount = pending.data?.length ?? 0;

  return (
    <>
      <PageHeader
        title={t('attendance.earlyExit.title')}
        subtitle={t('attendance.earlyExit.subtitle')}
        actions={
          <Can perm="attendance.earlyExit">
            <Button onClick={() => setCreateOpen(true)}>
              <Plus />
              {t('attendance.earlyExit.create')}
            </Button>
          </Can>
        }
      />

      <Tabs value={tab} onValueChange={(v) => setTab(v === 'all' ? 'all' : 'pending')} className="mb-4">
        <TabsList>
          <TabsTrigger value="pending">
            {t('attendance.earlyExit.tabPending')}
            {pendingCount > 0 && (
              <Badge variant="warning" size="sm" className="ml-1 tabular-nums">
                {formatNumber(pendingCount)}
              </Badge>
            )}
          </TabsTrigger>
          <TabsTrigger value="all">{t('attendance.earlyExit.tabAll')}</TabsTrigger>
        </TabsList>
      </Tabs>

      {list.error ? (
        <ErrorState error={list.error} onRetry={() => void list.refetch()} />
      ) : (
        <EarlyExitTable
          rows={list.data}
          loading={list.isLoading}
          canDecide={can('attendance.earlyExit')}
          emptyTitle={t(tab === 'pending' ? 'attendance.earlyExit.emptyPending' : 'attendance.earlyExit.emptyAll')}
          onDecide={onDecide}
        />
      )}

      <EarlyExitDialog open={createOpen} onOpenChange={setCreateOpen} />
      <ConfirmDialog
        open={Boolean(decision)}
        onOpenChange={(open) => !open && setDecision(null)}
        title={t(decision?.approve ? 'attendance.earlyExit.approveTitle' : 'attendance.earlyExit.rejectTitle')}
        description={
          decision
            ? t(decision.approve ? 'attendance.earlyExit.approveText' : 'attendance.earlyExit.rejectText', { name: decision.row.studentName, time: decision.row.time })
            : undefined
        }
        confirmLabel={t(decision?.approve ? 'attendance.earlyExit.approve' : 'attendance.earlyExit.reject')}
        destructive={decision ? !decision.approve : false}
        loading={decide.isPending}
        onConfirm={() => {
          if (!decision) return;
          decide.mutate({ id: decision.row.id, approve: decision.approve }, { onSuccess: () => setDecision(null) });
        }}
      />
    </>
  );
}
