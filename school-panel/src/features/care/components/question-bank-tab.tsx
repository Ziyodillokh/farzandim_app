'use client';

import { Pencil, Plus, Trash2 } from 'lucide-react';
import { useCallback, useMemo, useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { DataTable, type Column } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { FilterSelect, SearchInput, Toolbar } from '@/components/common/toolbar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import type { CareQuestion, CareTopic } from '@/data/contracts';
import type { CareQuestionRow } from '@/data/mock/services/care-surveys';
import { CARE_TOPICS } from '@/data/schemas/care';
import { useI18n } from '@/i18n';
import { matchesSearch } from '@/lib/normalize-search';
import { useCareQuestions, useDeleteQuestion } from '../hooks';
import { ageGroupsLabel, TOPIC_ICONS } from '../lib/labels';
import { QuestionFormDialog } from './question-form-dialog';

/** Savollar banki — CRUD (faqat psixolog). Ishlatilgan savolni o'chirib bo'lmaydi. */
export function QuestionBankTab() {
  const { t, tc, locale } = useI18n();
  const questions = useCareQuestions();
  const remove = useDeleteQuestion();
  const [search, setSearch] = useState('');
  const [topic, setTopic] = useState<CareTopic | undefined>();
  const [editing, setEditing] = useState<CareQuestion | undefined>();
  const [formOpen, setFormOpen] = useState(false);
  const [deleting, setDeleting] = useState<CareQuestionRow | null>(null);

  const openForm = useCallback((question?: CareQuestion) => {
    setEditing(question);
    setFormOpen(true);
  }, []);

  const rows = useMemo(
    () => (questions.data ?? []).filter((q) => (!topic || q.topic === topic) && matchesSearch(`${q.text.uz} ${q.text.ru}`, search)),
    [questions.data, topic, search],
  );

  const columns = useMemo<Column<CareQuestionRow>[]>(
    () => [
      {
        key: 'text',
        header: t('care.questions.columns.text'),
        cell: (q) => {
          const Icon = TOPIC_ICONS[q.topic];
          return (
            <div className="flex max-w-xl items-start gap-3">
              <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                <Icon className="h-3.5 w-3.5" />
              </span>
              <div>
                <p className="text-sm">{q.text[locale]}</p>
                {q.reverse && <Badge variant="outline" size="sm" className="mt-1">{t('care.questions.reverse')}</Badge>}
              </div>
            </div>
          );
        },
      },
      { key: 'topic', header: t('care.questions.columns.topic'), className: 'text-muted-foreground', cell: (q) => t(`enums.careTopic.${q.topic}`) },
      { key: 'ages', header: t('care.questions.columns.ageGroups'), className: 'text-muted-foreground', cell: (q) => ageGroupsLabel(t, q.ageGroups) },
      {
        key: 'usage',
        header: t('care.questions.columns.usage'),
        className: 'whitespace-nowrap text-muted-foreground',
        cell: (q) => (q.usedIn > 0 ? tc('care.questions.usedIn', q.usedIn) : t('care.questions.notUsed')),
      },
      {
        key: 'status',
        header: t('care.questions.columns.status'),
        cell: (q) => <Badge variant={q.active ? 'success' : 'secondary'}>{q.active ? t('care.questions.active') : t('care.questions.inactive')}</Badge>,
      },
      {
        key: 'actions',
        header: '',
        className: 'w-[96px] text-right',
        cell: (q) => (
          <div className="flex justify-end gap-1">
            <Button variant="ghost" size="icon-sm" onClick={() => openForm(q)} aria-label={t('common.edit')}>
              <Pencil />
            </Button>
            <Tooltip>
              <TooltipTrigger asChild>
                <span tabIndex={q.usedIn > 0 ? 0 : -1}>
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    className="text-destructive hover:text-destructive"
                    disabled={q.usedIn > 0}
                    onClick={() => setDeleting(q)}
                    aria-label={t('common.delete')}
                  >
                    <Trash2 />
                  </Button>
                </span>
              </TooltipTrigger>
              <TooltipContent>{q.usedIn > 0 ? t('care.questions.inUseHint') : t('common.delete')}</TooltipContent>
            </Tooltip>
          </div>
        ),
      },
    ],
    [t, tc, locale, openForm],
  );

  if (questions.error) return <ErrorState error={questions.error} onRetry={() => void questions.refetch()} />;

  return (
    <>
      <Toolbar>
        <SearchInput value={search} onChange={setSearch} placeholder={t('care.questions.searchPlaceholder')} />
        <FilterSelect
          value={topic}
          onChange={(v) => setTopic(v as CareTopic | undefined)}
          options={CARE_TOPICS.map((x) => ({ value: x, label: t(`enums.careTopic.${x}`) }))}
          allLabel={`${t('care.questions.columns.topic')}: ${t('common.all')}`}
          className="sm:w-60"
        />
        <Button className="ml-auto" onClick={() => openForm()}>
          <Plus />
          {t('care.questions.add')}
        </Button>
      </Toolbar>
      <DataTable
        columns={columns}
        rows={questions.data ? rows : undefined}
        rowKey={(q) => q.id}
        loading={questions.isLoading}
        skeletonRows={6}
        emptyTitle={t('care.questions.empty')}
      />
      <QuestionFormDialog open={formOpen} onOpenChange={setFormOpen} question={editing} />
      <ConfirmDialog
        open={Boolean(deleting)}
        onOpenChange={(open) => !open && setDeleting(null)}
        title={t('care.questions.deleteTitle')}
        description={deleting ? `«${deleting.text[locale]}» — ${t('care.questions.deleteDescription')}` : undefined}
        confirmLabel={t('common.delete')}
        destructive
        loading={remove.isPending}
        onConfirm={() => deleting && remove.mutate(deleting.id, { onSuccess: () => setDeleting(null) })}
      />
    </>
  );
}
