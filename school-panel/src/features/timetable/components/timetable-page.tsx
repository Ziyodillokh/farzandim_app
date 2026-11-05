'use client';

import { CalendarDays, Eye, TriangleAlert } from 'lucide-react';
import { useMemo, useState } from 'react';
import { toast } from 'sonner';

import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { ServiceError } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';
import { useUnsavedChangesGuard } from '@/lib/unsaved-changes';
import { useSaveTimetable, useTimetable, useTimetableClasses } from '../hooks';
import {
  type CellErrorKind,
  cellKey,
  filledCount,
  type Grid,
  lessonPeriods,
  mapSaveError,
  orphanLessons,
  type SaveErrorMap,
  setCell,
  toLessons,
  validateGrid,
} from '../lib/grid';
import { useTimetableDraft } from '../use-timetable-draft';
import { CellEditorDialog, type CellTarget } from './cell-editor-dialog';
import { CopyDayDialog } from './copy-day-dialog';
import { TimetableGrid } from './timetable-grid';
import { TimetableToolbar } from './timetable-toolbar';

const NO_ERRORS: Readonly<Record<string, CellErrorKind>> = {};

/** Sinf dars jadvali: ko'rish (`classes.view`) va tahrirlash (`timetable.manage`). */
export function TimetablePage() {
  const { t } = useI18n();
  const can = useCan();
  const canManage = can('timetable.manage');
  const classes = useTimetableClasses();
  const [pickedClass, setPickedClass] = useState<string | null>(null);
  const classId = pickedClass ?? classes.data?.[0]?.id ?? null;
  const timetable = useTimetable(classId);
  const draft = useTimetableDraft(classId, timetable.data);
  const save = useSaveTimetable(classId);
  const guard = useUnsavedChangesGuard(draft.isDirty);

  const [editing, setEditing] = useState<CellTarget | null>(null);
  const [copying, setCopying] = useState(false);
  const [pendingClass, setPendingClass] = useState<string | null>(null);
  const [saveErrors, setSaveErrors] = useState<SaveErrorMap | null>(null);

  const periods = useMemo(() => lessonPeriods(timetable.data?.shift.periods ?? []), [timetable.data]);
  const periodNos = useMemo(() => periods.map((p) => p.no), [periods]);
  const orphans = useMemo(() => (timetable.data ? orphanLessons(timetable.data.lessons, timetable.data.shift.periods).length : 0), [timetable.data]);
  const className = classes.data?.find((c) => c.id === classId)?.name ?? '';

  const switchClass = (id: string) => {
    setPickedClass(id);
    setSaveErrors(null);
    setPendingClass(null);
  };
  const requestClass = (id: string) => {
    if (id === classId) return;
    if (draft.isDirty) setPendingClass(id);
    else switchClass(id);
  };

  const changeGrid = (updater: (grid: Grid) => Grid) => {
    draft.update(updater);
    setSaveErrors(null);
  };

  const onApplyCell = (target: CellTarget, next: Parameters<typeof setCell>[3]) => {
    changeGrid((grid) => setCell(grid, target.weekday, target.period.no, next));
    setEditing(null);
  };

  const onSave = async () => {
    if (!timetable.data) return;
    const invalid = validateGrid(draft.draft, periods);
    if (Object.keys(invalid).length > 0) {
      setSaveErrors({ cells: invalid, hasUnmapped: false });
      toast.error(t('timetable.invalidCells'));
      return;
    }
    const lessons = toLessons(draft.draft, timetable.data.shift.periods);
    try {
      await save.mutateAsync(lessons);
      setSaveErrors(null);
      toast.success(t('timetable.saved'));
    } catch (error) {
      if (error instanceof ServiceError && error.code === 'VALIDATION') {
        setSaveErrors(mapSaveError(error.message, lessons));
        toast.error(t('timetable.saveFailed'));
      } else {
        toast.error(t(errorKey(error)));
      }
    }
  };

  const header = (
    <PageHeader
      title={t('timetable.title')}
      subtitle={t('timetable.subtitle')}
      badge={
        !canManage && (
          <Badge variant="info" className="gap-1">
            <Eye className="h-3 w-3" aria-hidden />
            {t('timetable.readOnly')}
          </Badge>
        )
      }
    />
  );

  if (classes.isError) return <>{header}<ErrorState error={classes.error} onRetry={() => void classes.refetch()} /></>;
  if (classes.isSuccess && classes.data.length === 0) {
    return <>{header}<Card><EmptyState icon={<CalendarDays />} title={t('timetable.noClasses')} /></Card></>;
  }

  const fieldErrors = saveErrors?.cells ?? NO_ERRORS;
  const editingValue = editing ? draft.draft[cellKey(editing.weekday, editing.period.no)] : undefined;
  const ready = Boolean(timetable.data) && draft.isReady;

  return (
    <>
      {header}
      <Card className="space-y-5 p-5">
        <TimetableToolbar
          classes={classes.data ?? []}
          classId={classId ?? ''}
          onClassChange={requestClass}
          shiftName={timetable.data?.shift.name ?? null}
          lessonCount={filledCount(draft.draft)}
          canManage={canManage}
          isDirty={draft.isDirty}
          isSaving={save.isPending}
          onCopy={() => setCopying(true)}
          onDiscard={() => {
            draft.discard();
            setSaveErrors(null);
          }}
          onSave={() => void onSave()}
        />

        {!canManage && <p className="text-sm text-muted-foreground">{t('timetable.readOnlyHint')}</p>}
        {saveErrors?.hasUnmapped && (
          <p role="alert" className="flex items-center gap-2 rounded-xl bg-destructive/10 px-3 py-2 text-sm font-medium text-destructive">
            <TriangleAlert className="h-4 w-4 shrink-0" aria-hidden />
            {t(Object.keys(saveErrors.cells).length > 0 ? 'timetable.saveFailed' : 'timetable.saveFailedGeneral')}
          </p>
        )}
        {orphans > 0 && (
          <p role="status" className="flex items-center gap-2 rounded-xl bg-warning/10 px-3 py-2 text-sm text-warning">
            <TriangleAlert className="h-4 w-4 shrink-0" aria-hidden />
            {t('timetable.orphan', { count: orphans })}
          </p>
        )}

        {timetable.isError ? (
          <ErrorState error={timetable.error} onRetry={() => void timetable.refetch()} />
        ) : !ready ? (
          <Skeleton className="h-[26rem] rounded-2xl" />
        ) : periods.length === 0 ? (
          <EmptyState icon={<CalendarDays />} title={t('timetable.noPeriods')} />
        ) : (
          <TimetableGrid periods={periods} grid={draft.draft} errors={fieldErrors} readOnly={!canManage} className={className} onEdit={(weekday, period) => setEditing({ weekday, period })} />
        )}
      </Card>

      {editing && <CellEditorDialog key={cellKey(editing.weekday, editing.period.no)} target={editing} value={editingValue} onApply={(next) => onApplyCell(editing, next)} onClose={() => setEditing(null)} />}
      {copying && (
        <CopyDayDialog
          grid={draft.draft}
          periodNos={periodNos}
          onClose={() => setCopying(false)}
          onApply={(next) => {
            changeGrid(() => next);
            setCopying(false);
          }}
        />
      )}
      <ConfirmDialog
        open={pendingClass !== null || guard.pendingRoute !== null}
        onOpenChange={(open) => {
          if (open) return;
          setPendingClass(null);
          guard.stay();
        }}
        title={t('timetable.leave.title')}
        description={t('timetable.leave.description')}
        confirmLabel={t('timetable.leave.confirm')}
        destructive
        onConfirm={() => {
          if (pendingClass) switchClass(pendingClass);
          else guard.proceed();
        }}
      />
    </>
  );
}
