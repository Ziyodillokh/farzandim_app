'use client';

import { Clock3, GraduationCap, Plus } from 'lucide-react';
import { useMemo, useState } from 'react';

import { Can } from '@/auth/can';
import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { ClassRow } from '@/data/mock/services/classes';
import { ClassCard } from '@/features/classes/components/class-card';
import { ClassFormDialog } from '@/features/classes/components/class-form-dialog';
import { ClassesStats } from '@/features/classes/components/classes-stats';
import { type ClassFilter, useClasses, useClassModes, useDeleteClass, useTodayBoard } from '@/features/classes/hooks';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';

const SKELETON_CARDS = 8;

export default function ClassesPage() {
  const { t, tc } = useI18n();
  const can = useCan();
  const canManage = can('classes.manage');
  const canSeeAttendance = can('attendance.view');
  const [filter, setFilter] = useState<ClassFilter>({});
  const [createOpen, setCreateOpen] = useState(false);
  const [editing, setEditing] = useState<ClassRow | null>(null);
  const [deleting, setDeleting] = useState<ClassRow | null>(null);

  const classes = useClasses(filter);
  const board = useTodayBoard(canSeeAttendance);
  const modes = useClassModes();
  const school = useSchool();
  const remove = useDeleteClass();

  const shifts = useMemo(() => school.data?.shifts ?? [], [school.data]);
  const rows = useMemo(() => classes.data ?? [], [classes.data]);
  const boardById = useMemo(() => new Map((board.data?.rows ?? []).map((b) => [b.classId, b])), [board.data]);
  const groups = useMemo(
    () =>
      shifts
        .map((shift) => ({ shift, rows: rows.filter((r) => r.shiftId === shift.id) }))
        .filter((g) => g.rows.length > 0),
    [shifts, rows],
  );

  const confirmDelete = async () => {
    if (!deleting) return;
    try {
      await remove.mutateAsync(deleting.id);
      setDeleting(null);
    } catch {
      // toast — hooks ichida
    }
  };

  return (
    <>
      <PageHeader
        title={t('classes.title')}
        subtitle={t('classes.subtitle')}
        actions={
          <Can perm="classes.manage">
            <Button onClick={() => setCreateOpen(true)}>
              <Plus />
              {t('classes.add')}
            </Button>
          </Can>
        }
      />

      <ClassesStats rows={rows} board={board.data?.rows} loading={classes.isLoading} showAttendance={canSeeAttendance} />

      <Toolbar>
        <SearchInput value={filter.search ?? ''} onChange={(search) => setFilter((f) => ({ ...f, search }))} placeholder={t('classes.searchPlaceholder')} />
        <FilterSelect
          value={filter.shiftId}
          onChange={(shiftId) => setFilter((f) => ({ ...f, shiftId }))}
          options={shifts.map((s) => ({ value: s.id, label: s.name }))}
          allLabel={t('classes.allShifts')}
          className="sm:w-44"
        />
      </Toolbar>

      {classes.isError ? (
        <Card>
          <ErrorState error={classes.error} onRetry={() => void classes.refetch()} />
        </Card>
      ) : classes.isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
          {Array.from({ length: SKELETON_CARDS }).map((_, i) => (
            <Skeleton key={i} className="h-[268px] rounded-2xl" />
          ))}
        </div>
      ) : groups.length === 0 ? (
        <Card>
          <EmptyState icon={<GraduationCap />} title={t('classes.empty')} description={t('classes.emptyHint')} />
        </Card>
      ) : (
        <div className="space-y-8">
          {groups.map(({ shift, rows: shiftRows }) => (
            <section key={shift.id} className="animate-fade-in">
              <div className="mb-4 flex flex-wrap items-center gap-3">
                <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/15">
                  <Clock3 className="h-[18px] w-[18px]" />
                </span>
                <div className="min-w-0">
                  <h2 className="font-display text-lg font-semibold leading-tight tracking-[-0.01em]">{shift.name}</h2>
                  <p className="text-xs tabular-nums text-muted-foreground">
                    {t('classes.shiftGroup', { start: shift.start, end: shift.end })} · {tc('common.classesCount', shiftRows.length)}
                  </p>
                </div>
                <span aria-hidden className="ml-2 hidden h-px flex-1 bg-gradient-to-r from-border to-transparent sm:block" />
              </div>
              <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
                {shiftRows.map((row) => (
                  <ClassCard
                    key={row.id}
                    row={row}
                    board={boardById.get(row.id)}
                    mode={modes.data?.[row.id]}
                    canManage={canManage}
                    canSeeAttendance={canSeeAttendance}
                    onEdit={setEditing}
                    onDelete={setDeleting}
                  />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}

      <ClassFormDialog open={createOpen} onOpenChange={setCreateOpen} />
      <ClassFormDialog open={Boolean(editing)} onOpenChange={(open) => !open && setEditing(null)} row={editing ?? undefined} />
      <ConfirmDialog
        open={Boolean(deleting)}
        onOpenChange={(open) => !open && setDeleting(null)}
        title={t('classes.delete.title', { name: deleting?.name ?? '' })}
        description={t('classes.delete.text')}
        confirmLabel={t('common.delete')}
        destructive
        loading={remove.isPending}
        onConfirm={() => void confirmDelete()}
      />
    </>
  );
}
