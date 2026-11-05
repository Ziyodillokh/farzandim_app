'use client';

import { ClipboardCheck, ClipboardList, Plus, Trash2 } from 'lucide-react';
import { useMemo, useState } from 'react';

import { Can } from '@/auth/can';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { DataTable, type Column } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { fromIsoDate } from '@/data/mock/calendar';
import { clockToday } from '@/data/mock/clock';
import type { AssignmentRow } from '@/data/mock/services/learning';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useDeleteAssignment, useLearningAssignments } from '../hooks';
import { assignmentKind, assignmentTitle, isWrittenAssignment, KIND_ICONS, KIND_TONES } from '../lib/format';
import { AssignmentFormDialog } from './assignment-form-dialog';
import { SubmissionCounter } from './submission-counter';
import { SubmissionsSheet } from './submissions-sheet';

const DAY_MS = 86_400_000;

function daysUntil(date: string): number {
  return Math.round((fromIsoDate(date).getTime() - fromIsoDate(clockToday()).getTime()) / DAY_MS);
}

/** Topshiriqlar ro'yxati; yaratish va o'chirish — `learning.assign` (sinf rahbari — o'z sinfi). */
export function AssignmentsTab() {
  const { t, tc, formatDate } = useI18n();
  const assignments = useLearningAssignments();
  const remove = useDeleteAssignment();
  const [createOpen, setCreateOpen] = useState(false);
  const [deleting, setDeleting] = useState<AssignmentRow | null>(null);
  const [viewingId, setViewingId] = useState<string | null>(null);
  const viewing = assignments.data?.find((a) => a.id === viewingId) ?? null;

  const columns = useMemo<Column<AssignmentRow>[]>(
    () => [
      {
        key: 'material',
        header: t('learning.assignments.columns.material'),
        cell: (a) => {
          const kind = assignmentKind(a);
          const Icon = kind ? KIND_ICONS[kind] : ClipboardList;
          return (
            <div className="flex items-center gap-3">
              <span className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-xl ring-1 ring-inset', kind ? KIND_TONES[kind] : 'bg-muted ring-border')}>
                <Icon className="h-4 w-4" />
              </span>
              <div className="min-w-0">
                <p className="truncate font-medium">{assignmentTitle(a)}</p>
                <p className="text-xs text-muted-foreground">
                  {[
                    a.subject ? t(`enums.subject.${a.subject}`) : null,
                    kind ? t(`enums.materialKind.${kind}`) : null,
                    a.estimatedMinutes ? t('learning.assignments.estimated', { count: a.estimatedMinutes }) : null,
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                </p>
              </div>
            </div>
          );
        },
      },
      {
        key: 'classes',
        header: t('learning.assignments.columns.classes'),
        cell: (a) => (
          <div className="flex flex-wrap gap-1">
            {a.classNames.map((n) => (
              <Badge key={n} variant="outline" size="sm">{n}</Badge>
            ))}
          </div>
        ),
      },
      {
        key: 'due',
        header: t('learning.assignments.columns.due'),
        className: 'whitespace-nowrap',
        cell: (a) => {
          const days = daysUntil(a.dueDate);
          return (
            <div>
              <p className="text-sm tabular-nums">{formatDate(a.dueDate, 'd MMM yyyy')}</p>
              {a.overdue ? (
                <Badge variant="destructive" size="sm">{t('learning.assignments.overdue')}</Badge>
              ) : days === 0 ? (
                <Badge variant="warning" size="sm">{t('learning.assignments.dueToday')}</Badge>
              ) : (
                <span className="text-xs text-muted-foreground">{tc('learning.assignments.daysLeft', days)}</span>
              )}
            </div>
          );
        },
      },
      {
        key: 'submissions',
        header: t('learning.assignments.columns.submissions'),
        cell: (a) =>
          isWrittenAssignment(a) ? (
            <div className="flex flex-col items-start gap-2">
              <SubmissionCounter assignment={a} />
              <Button type="button" size="sm" variant="outline" onClick={() => setViewingId(a.id)} aria-label={`${t('learning.submissions.open')}: ${assignmentTitle(a)}`}>
                <ClipboardCheck />
                {t('learning.submissions.open')}
              </Button>
            </div>
          ) : (
            <span className="text-muted-foreground">—</span>
          ),
      },
      {
        key: 'note',
        header: t('learning.assignments.columns.note'),
        className: 'min-w-[160px] max-w-[220px] text-sm text-muted-foreground',
        cell: (a) => (a.note ? <span className="line-clamp-3" title={a.note}>{a.note}</span> : '—'),
      },
      { key: 'by', header: t('learning.assignments.columns.by'), className: 'max-w-[140px] text-sm text-muted-foreground', cell: (a) => a.byName },
      {
        key: 'actions',
        header: '',
        className: 'w-[56px] text-right',
        cell: (a) =>
          a.canDelete && (
            <Button variant="ghost" size="icon-sm" className="text-destructive hover:text-destructive" onClick={() => setDeleting(a)} aria-label={t('common.delete')}>
              <Trash2 />
            </Button>
          ),
      },
    ],
    [t, tc, formatDate],
  );

  if (assignments.error) return <ErrorState error={assignments.error} onRetry={() => void assignments.refetch()} />;

  return (
    <>
      <Can perm="learning.assign">
        <div className="mb-4 flex justify-end">
          <Button onClick={() => setCreateOpen(true)}>
            <Plus />
            {t('learning.assignments.create')}
          </Button>
        </div>
      </Can>
      <DataTable
        columns={columns}
        rows={assignments.data}
        rowKey={(a) => a.id}
        loading={assignments.isLoading}
        skeletonRows={5}
        emptyTitle={t('learning.assignments.empty')}
        emptyDescription={t('learning.assignments.emptyHint')}
      />
      <AssignmentFormDialog open={createOpen} onOpenChange={setCreateOpen} />
      <SubmissionsSheet assignment={viewing} onClose={() => setViewingId(null)} />
      <ConfirmDialog
        open={Boolean(deleting)}
        onOpenChange={(open) => !open && setDeleting(null)}
        title={t('learning.assignments.deleteTitle')}
        description={deleting ? `«${assignmentTitle(deleting)}» — ${t('learning.assignments.deleteDescription')}` : undefined}
        confirmLabel={t('common.delete')}
        destructive
        loading={remove.isPending}
        onConfirm={() => deleting && remove.mutate(deleting.id, { onSuccess: () => setDeleting(null) })}
      />
    </>
  );
}
