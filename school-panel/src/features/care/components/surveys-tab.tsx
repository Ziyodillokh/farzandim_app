'use client';

import { CircleStop, ListChecks, Pencil, Plus, Power, Trash2 } from 'lucide-react';
import { type ReactNode, useCallback, useMemo, useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { DataTable, type Column } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { Badge, type BadgeProps } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import type { CareSurvey, CareSurveyStatus } from '@/data/contracts';
import type { CareSurveyRow } from '@/data/mock/services/care-surveys';
import { useI18n } from '@/i18n';
import { useActivateSurvey, useCareSurveys, useCloseSurvey, useDeleteSurvey } from '../hooks';
import { ageGroupsLabel } from '../lib/labels';
import { SurveyFormDialog } from './survey-form-dialog';

const STATUS_VARIANT: Record<CareSurveyStatus, NonNullable<BadgeProps['variant']>> = { DRAFT: 'secondary', ACTIVE: 'success', CLOSED: 'outline' };
type Pending = { kind: 'activate' | 'close' | 'delete'; survey: CareSurvey } | null;

function IconAction({ label, onClick, children, destructive }: { label: string; onClick: () => void; children: ReactNode; destructive?: boolean }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button variant="ghost" size="icon-sm" onClick={onClick} aria-label={label} className={destructive ? 'text-destructive hover:text-destructive' : undefined}>
          {children}
        </Button>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
}

/** So'rovnomalar ro'yxati: yaratish, tahrirlash (qoralama), faollashtirish, yakunlash. */
export function SurveysTab() {
  const { t, formatDate } = useI18n();
  const surveys = useCareSurveys();
  const activate = useActivateSurvey();
  const close = useCloseSurvey();
  const remove = useDeleteSurvey();
  const [editing, setEditing] = useState<CareSurvey | undefined>();
  const [formOpen, setFormOpen] = useState(false);
  const [pending, setPending] = useState<Pending>(null);

  const openForm = useCallback((survey?: CareSurvey) => {
    setEditing(survey);
    setFormOpen(true);
  }, []);

  const columns = useMemo<Column<CareSurveyRow>[]>(
    () => [
      {
        key: 'title',
        header: t('care.surveys.columns.title'),
        cell: (s) => <span className="font-medium">{s.title}</span>,
      },
      { key: 'week', header: t('care.surveys.columns.week'), className: 'whitespace-nowrap text-muted-foreground', cell: (s) => formatDate(s.weekStart, 'd MMM yyyy') },
      { key: 'ages', header: t('care.surveys.columns.ageGroups'), className: 'text-muted-foreground', cell: (s) => ageGroupsLabel(t, s.ageGroups) },
      { key: 'questions', header: t('care.surveys.columns.questions'), className: 'tabular-nums', cell: (s) => s.questionIds.length },
      {
        key: 'participation',
        header: t('care.surveys.columns.participation'),
        cell: (s) => (
          <div className="min-w-[120px]">
            <div className="mb-1 flex justify-between text-xs tabular-nums">
              <span className="font-semibold">{s.participationRate}%</span>
              <span className="text-muted-foreground">{t('care.surveys.responses', { count: s.respondents, invited: s.invited })}</span>
            </div>
            <Progress value={s.participationRate} className="h-1.5" />
          </div>
        ),
      },
      { key: 'status', header: t('care.surveys.columns.status'), cell: (s) => <Badge variant={STATUS_VARIANT[s.status]}>{t(`enums.surveyStatus.${s.status}`)}</Badge> },
      {
        key: 'actions',
        header: '',
        className: 'w-[120px] text-right',
        cell: (s) => (
          <div className="flex justify-end gap-1">
            {s.status === 'DRAFT' && (
              <>
                <IconAction label={t('common.edit')} onClick={() => openForm(s)}><Pencil /></IconAction>
                <IconAction label={t('care.surveys.activate')} onClick={() => setPending({ kind: 'activate', survey: s })}><Power /></IconAction>
                <IconAction label={t('common.delete')} destructive onClick={() => setPending({ kind: 'delete', survey: s })}><Trash2 /></IconAction>
              </>
            )}
            {s.status === 'ACTIVE' && (
              <IconAction label={t('care.surveys.close')} onClick={() => setPending({ kind: 'close', survey: s })}><CircleStop /></IconAction>
            )}
          </div>
        ),
      },
    ],
    [t, formatDate, openForm],
  );

  const confirm = () => {
    if (!pending) return;
    const done = { onSuccess: () => setPending(null) };
    if (pending.kind === 'activate') activate.mutate(pending.survey.id, done);
    else if (pending.kind === 'close') close.mutate(pending.survey.id, done);
    else remove.mutate(pending.survey.id, done);
  };

  const copy = pending
    ? {
        activate: { title: t('care.surveys.activateTitle'), description: t('care.surveys.activateDescription'), label: t('care.surveys.activate') },
        close: { title: t('care.surveys.closeTitle'), description: t('care.surveys.closeDescription'), label: t('care.surveys.close') },
        delete: { title: t('care.surveys.deleteTitle'), description: t('care.surveys.deleteDescription'), label: t('common.delete') },
      }[pending.kind]
    : null;

  if (surveys.error) return <ErrorState error={surveys.error} onRetry={() => void surveys.refetch()} />;

  return (
    <>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-muted-foreground">{t('care.surveys.consentNote')}</p>
        <Button onClick={() => openForm()}>
          <Plus />
          {t('care.surveys.create')}
        </Button>
      </div>
      <DataTable
        columns={columns}
        rows={surveys.data}
        rowKey={(s) => s.id}
        loading={surveys.isLoading}
        skeletonRows={4}
        emptyTitle={t('care.surveys.empty')}
        emptyDescription={t('care.surveys.emptyHint')}
        emptyAction={<Button variant="soft" onClick={() => openForm()}><ListChecks />{t('care.surveys.create')}</Button>}
      />
      <SurveyFormDialog open={formOpen} onOpenChange={setFormOpen} survey={editing} />
      <ConfirmDialog
        open={Boolean(pending)}
        onOpenChange={(open) => !open && setPending(null)}
        title={copy?.title ?? ''}
        description={copy?.description}
        confirmLabel={copy?.label}
        destructive={pending?.kind === 'delete'}
        loading={activate.isPending || close.isPending || remove.isPending}
        onConfirm={confirm}
      />
    </>
  );
}
