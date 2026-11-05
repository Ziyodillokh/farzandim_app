'use client';

import { useMemo, useState } from 'react';

import { useCan } from '@/auth/use-session';
import { type Column, DataTable } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { Button } from '@/components/ui/button';
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import type { StudentSubmissionRow } from '@/data/contracts';
import type { AssignmentRow } from '@/data/mock/services/learning';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useAssignmentSubmissions, useLearningClassOptions } from '../hooks';
import { assignmentTitle } from '../lib/format';
import { countSubmissions, filterRows, stateOf, type SubmissionFilter } from '../lib/submissions';
import { ReviewDrawer } from './review-drawer';
import { SubmissionStatusChip } from './submission-status';

const FILTERS: readonly SubmissionFilter[] = ['ALL', 'SUBMITTED', 'ACCEPTED', 'RETURNED', 'NOT_SUBMITTED'];

/** Yozma vazifa topshiriqlari: o'quvchilar jadvali (holat belgilari, filtr) va tekshirish paneli. */
export function SubmissionsSheet({ assignment, onClose }: { assignment: AssignmentRow | null; onClose: () => void }) {
  const { t, tc, formatDate } = useI18n();
  const can = useCan();
  const query = useAssignmentSubmissions(assignment?.id ?? null);
  const classes = useLearningClassOptions();
  const [filter, setFilter] = useState<SubmissionFilter>('ALL');
  const [selected, setSelected] = useState<string | null>(null);

  const rows = useMemo(() => query.data ?? [], [query.data]);
  const counts = useMemo(() => countSubmissions(rows), [rows]);
  const visible = useMemo(() => filterRows(rows, filter), [rows, filter]);
  const className = (classId: string) => classes.data?.find((c) => c.id === classId)?.name ?? '—';
  const selectedRow = rows.find((r) => r.student.id === selected) ?? null;
  /** Yopilganda filtr va tanlov tozalanadi — keyingi topshiriq toza holatda ochiladi. */
  const close = () => {
    setFilter('ALL');
    setSelected(null);
    onClose();
  };

  const columns = useMemo<Column<StudentSubmissionRow>[]>(
    () => [
      { key: 'student', header: t('learning.submissions.columns.student'), className: 'font-medium', cell: (r) => r.student.fullName },
      { key: 'class', header: t('learning.submissions.columns.class'), className: 'whitespace-nowrap text-muted-foreground', cell: (r) => classes.data?.find((c) => c.id === r.classId)?.name ?? '—' },
      { key: 'status', header: t('learning.submissions.columns.status'), cell: (r) => <SubmissionStatusChip state={stateOf(r)} size="sm" /> },
      {
        key: 'sent',
        header: t('learning.submissions.columns.submittedAt'),
        className: 'whitespace-nowrap text-sm tabular-nums text-muted-foreground',
        cell: (r) => (r.submission ? formatDate(r.submission.submittedAt, 'd MMM, HH:mm') : '—'),
      },
      {
        key: 'photos',
        header: t('learning.submissions.columns.photos'),
        className: 'whitespace-nowrap text-sm text-muted-foreground',
        cell: (r) => (r.submission ? tc('learning.submissions.photosCount', r.submission.photos.length) : '—'),
      },
      {
        key: 'open',
        header: <span className="sr-only">{t('common.actions')}</span>,
        className: 'w-[1%] text-right',
        cell: (r) => (
          <Button type="button" size="sm" variant={stateOf(r) === 'SUBMITTED' && can('learning.assign') ? 'soft' : 'ghost'} onClick={() => setSelected(r.student.id)} aria-label={`${t('learning.submissions.view')}: ${r.student.fullName}`}>
            {t('learning.submissions.view')}
          </Button>
        ),
      },
    ],
    [t, tc, formatDate, classes.data, can],
  );

  const summary: Array<{ key: string; label: string; value: number; emphasis?: boolean }> = [
    { key: 'total', label: t('learning.submissions.summary.total'), value: counts.total },
    { key: 'submitted', label: t('learning.submissions.summary.submitted'), value: counts.submitted },
    { key: 'pending', label: t('learning.submissions.summary.pending'), value: counts.pending, emphasis: counts.pending > 0 },
    { key: 'accepted', label: t('learning.submissions.summary.accepted'), value: counts.accepted },
    { key: 'returned', label: t('learning.submissions.summary.returned'), value: counts.returned },
  ];

  return (
    <>
      <Sheet open={assignment !== null} onOpenChange={(open) => !open && close()}>
        <SheetContent className="w-[calc(100%-1rem)] overflow-y-auto sm:max-w-3xl">
          <SheetHeader>
            <SheetTitle className="pr-8">{assignment ? assignmentTitle(assignment) : t('learning.submissions.title')}</SheetTitle>
            <SheetDescription>
              {assignment ? `${assignment.classNames.join(', ')} · ${formatDate(assignment.dueDate, 'd MMM yyyy')}` : t('learning.submissions.title')}
            </SheetDescription>
          </SheetHeader>
          <div className="space-y-5 p-6">
            <dl className="grid grid-cols-2 gap-2 sm:grid-cols-5">
              {summary.map((s) => (
                <div key={s.key} className={cn('rounded-xl px-3 py-2 ring-1 ring-inset', s.emphasis ? 'bg-info/[0.08] ring-info/30' : 'bg-white/50 ring-border/60 dark:bg-white/[0.03]')}>
                  <dt className="text-2xs font-medium text-muted-foreground">{s.label}</dt>
                  <dd className="text-lg font-semibold tabular-nums">{s.value}</dd>
                </div>
              ))}
            </dl>

            <div role="group" aria-label={t('learning.submissions.filterLabel')} className="flex flex-wrap gap-1.5">
              {FILTERS.map((f) => {
                const on = filter === f;
                return (
                  <button
                    key={f}
                    type="button"
                    aria-pressed={on}
                    onClick={() => setFilter(f)}
                    className={cn(
                      'rounded-full px-3 py-1 text-xs font-semibold ring-1 ring-inset transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
                      on ? 'bg-primary/15 text-primary ring-primary/30' : 'text-muted-foreground ring-border/60 hover:text-foreground',
                    )}
                  >
                    {f === 'ALL' ? t('learning.submissions.all') : t(`learning.submissions.states.${f}`)}
                  </button>
                );
              })}
            </div>

            {query.isError ? (
              <ErrorState error={query.error} onRetry={() => void query.refetch()} />
            ) : (
              <DataTable
                columns={columns}
                rows={query.data ? visible : undefined}
                rowKey={(r) => r.student.id}
                loading={query.isLoading}
                skeletonRows={6}
                onRowClick={(r) => setSelected(r.student.id)}
                emptyTitle={t(rows.length === 0 ? 'learning.submissions.empty' : 'learning.submissions.emptyFilter')}
              />
            )}
          </div>
        </SheetContent>
      </Sheet>
      {assignment && (
        <ReviewDrawer
          assignmentId={assignment.id}
          row={selectedRow}
          rows={rows}
          className={selectedRow ? className(selectedRow.classId) : ''}
          canReview={can('learning.assign')}
          onClose={() => setSelected(null)}
          onSelectStudent={setSelected}
          onReload={() => void query.refetch()}
        />
      )}
    </>
  );
}
