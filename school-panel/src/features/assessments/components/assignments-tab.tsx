'use client';

import { CircleStop, Play, Send, XCircle } from 'lucide-react';
import Link from 'next/link';
import { type ReactNode, useMemo, useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { type Column, DataTable } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { FilterSelect, Toolbar } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import type { AssignmentState } from '@/data/contracts';
import { isHttpMode } from '@/data/source';
import type { AssignmentRow } from '@/data/mock/services/assessments';
import { useI18n } from '@/i18n';
import { percent } from '@/lib/utils';
import { useAssignments, useCloseAssignment, useSimulateCompletion, useUnassign } from '../hooks';
import { KindIcon, StateBadge } from './test-badges';
import { viewHref } from './test-card';

const STATES: readonly AssignmentState[] = ['SCHEDULED', 'ACTIVE', 'ENDED', 'CANCELLED'];
const MAX_CLASS_CHIPS = 3;
type Pending = { kind: 'close' | 'cancel'; row: AssignmentRow } | null;

function IconAction({ label, onClick, children, disabled, testId }: { label: string; onClick: () => void; children: ReactNode; disabled?: boolean; testId?: string }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button variant="ghost" size="icon-sm" onClick={onClick} aria-label={label} disabled={disabled} data-testid={testId}>
          {children}
        </Button>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}

/** Tayinlashlar: muddat, holat, yakunlaganlar va amallar (demo simulyatsiya, yopish, bekor qilish). */
export function AssignmentsTab({ onAssign, testId }: { onAssign: () => void; testId?: string }) {
  const { t, locale, formatDate } = useI18n();
  const [state, setState] = useState<AssignmentState | undefined>();
  const list = useAssignments({ state, testId });
  const simulate = useSimulateCompletion();
  const close = useCloseAssignment();
  const unassign = useUnassign();
  const [pending, setPending] = useState<Pending>(null);

  const columns = useMemo<Column<AssignmentRow>[]>(
    () => [
      {
        key: 'test',
        header: t('assessments.assignments.columns.test'),
        cell: (a) => (
          <div className="flex min-w-[200px] items-center gap-3">
            {a.testKind && <KindIcon kind={a.testKind} className="h-8 w-8 [&_svg]:size-4" />}
            <Link href={viewHref(a.testId)} className="font-medium hover:text-primary">
              {a.testTitle[locale]}
            </Link>
          </div>
        ),
      },
      {
        key: 'classes',
        header: t('assessments.assignments.columns.classes'),
        cell: (a) => (
          <div className="flex max-w-[220px] flex-wrap gap-1">
            {a.classNames.slice(0, MAX_CLASS_CHIPS).map((n) => (
              <Badge key={n} variant="outline" size="sm">
                {n}
              </Badge>
            ))}
            {a.classNames.length > MAX_CLASS_CHIPS && (
              <Badge variant="secondary" size="sm">
                {t('assessments.assignments.more', { count: a.classNames.length - MAX_CLASS_CHIPS })}
              </Badge>
            )}
          </div>
        ),
      },
      {
        key: 'window',
        header: t('assessments.assignments.columns.window'),
        className: 'whitespace-nowrap text-sm text-muted-foreground tabular-nums',
        cell: (a) => (
          <span>
            {formatDate(a.opensAt, 'd MMM, HH:mm')} — {formatDate(a.closesAt, 'd MMM, HH:mm')}
          </span>
        ),
      },
      { key: 'state', header: t('assessments.assignments.columns.state'), cell: (a) => <StateBadge state={a.state} /> },
      {
        key: 'progress',
        header: t('assessments.assignments.columns.progress'),
        cell: (a) => {
          const rate = percent(a.completed, a.invited);
          return (
            <div className="min-w-[130px]">
              <div className="mb-1 flex justify-between text-xs tabular-nums">
                <span className="font-semibold">{rate}%</span>
                <span className="text-muted-foreground">{t('assessments.assignments.progress', { completed: a.completed, invited: a.invited })}</span>
              </div>
              <Progress value={rate} className="h-1.5" />
            </div>
          );
        },
      },
      {
        key: 'actions',
        header: '',
        className: 'w-[120px] text-right',
        cell: (a) => (
          <div className="flex justify-end gap-1">
            {a.state === 'ACTIVE' && !isHttpMode && (
              <IconAction label={t('assessments.assignments.simulate')} onClick={() => simulate.mutate(a.id)} disabled={simulate.isPending} testId={`simulate-${a.id}`}>
                <Play />
              </IconAction>
            )}
            {a.status === 'OPEN' && a.state !== 'ENDED' && (
              <>
                <IconAction label={t('assessments.assignments.close')} onClick={() => setPending({ kind: 'close', row: a })}>
                  <CircleStop />
                </IconAction>
                <IconAction label={t('assessments.assignments.cancel')} onClick={() => setPending({ kind: 'cancel', row: a })}>
                  <XCircle />
                </IconAction>
              </>
            )}
          </div>
        ),
      },
    ],
    [t, locale, formatDate, simulate],
  );

  const confirm = () => {
    if (!pending) return;
    const done = { onSuccess: () => setPending(null) };
    if (pending.kind === 'close') close.mutate(pending.row.id, done);
    else unassign.mutate(pending.row.id, done);
  };

  if (list.error) return <ErrorState error={list.error} onRetry={() => void list.refetch()} />;

  return (
    <>
      <Toolbar>
        <FilterSelect
          value={state}
          onChange={(v) => setState(v as AssignmentState | undefined)}
          options={STATES.map((s) => ({ value: s, label: t(`enums.assignmentState.${s}`) }))}
          allLabel={`${t('assessments.assignments.stateFilter')}: ${t('common.all')}`}
          className="sm:w-56"
        />
        <Button className="w-full sm:ml-auto sm:w-auto" onClick={onAssign}>
          <Send />
          {t('assessments.assignments.create')}
        </Button>
      </Toolbar>
      <DataTable
        columns={columns}
        rows={list.data}
        rowKey={(a) => a.id}
        loading={list.isLoading}
        skeletonRows={4}
        emptyTitle={t('assessments.assignments.empty')}
        emptyDescription={t('assessments.assignments.emptyHint')}
        emptyAction={
          <Button variant="soft" onClick={onAssign}>
            <Send />
            {t('assessments.assignments.create')}
          </Button>
        }
      />
      <ConfirmDialog
        open={Boolean(pending)}
        onOpenChange={(open) => !open && setPending(null)}
        title={pending?.kind === 'close' ? t('assessments.assignments.closeTitle') : t('assessments.assignments.cancelTitle')}
        description={pending?.kind === 'close' ? t('assessments.assignments.closeDescription') : t('assessments.assignments.cancelDescription')}
        confirmLabel={pending?.kind === 'close' ? t('assessments.assignments.close') : t('assessments.assignments.cancel')}
        destructive={pending?.kind === 'cancel'}
        loading={close.isPending || unassign.isPending}
        onConfirm={confirm}
      />
    </>
  );
}
