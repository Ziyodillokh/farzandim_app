'use client';

/**
 * Mavzuga savol biriktirish paneli.
 *
 * `GET /admin/learning/questions` (fan + `topicId` filtri) ro'yxatidan savollar
 * tanlanadi va `POST /admin/learning/topics/:id/questions` bilan biriktiriladi.
 * Rejimlar: shu mavzudagi / mavzusiz / barchasi. Tanlov qidiruv va rejim
 * almashganda saqlanadi, panel yopilganda tozalanadi.
 */

import { useMemo, useState } from 'react';
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { AlertTriangle, Link2, Loader2, Search } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet';
import { EmptyState } from '@/components/common/empty-state';
import { useDebouncedValue } from '@/components/kelajak/use-debounced-value';
import { learningQuestionsApi, learningTopicsApi } from '@/lib/api/admin.api';
import {
  MIN_TOPIC_QUESTIONS,
  QUESTION_STATUS_LABELS,
  gradeRangeLabel,
  subjectLabel,
} from '@/lib/constants/learning';
import { cn } from '@/lib/utils';
import type { LearningQuestion, LearningTopic } from '@/types/api.types';
import { topicErrorMessage } from './topic-errors';
import { learningKeys } from './topic-keys';
import {
  EMPTY_SELECTION,
  QUESTION_SCOPES,
  countMoved,
  fetchQuestionsPage,
  flattenPages,
  isSelectable,
  overlapsGrades,
  toggleAllVisible,
  toggleSelected,
  type QuestionScope,
  type Selection,
} from './topic-questions';
import { WARNING_BADGE, WARNING_TEXT } from './warning-styles';

const SEARCH_DEBOUNCE_MS = 350;

export function TopicQuestionsSheet({
  topic,
  topicsById,
  onOpenChange,
}: {
  /** `null` — panel yopiq. */
  topic: LearningTopic | null;
  /** Savol qaysi mavzuda ekanini nom bilan ko'rsatish uchun. */
  topicsById: ReadonlyMap<string, LearningTopic>;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Sheet open={topic !== null} onOpenChange={onOpenChange}>
      <SheetContent className="w-full gap-0 p-0 sm:max-w-2xl">
        {topic && <SheetBody key={topic.id} topic={topic} topicsById={topicsById} />}
      </SheetContent>
    </Sheet>
  );
}

function SheetBody({
  topic,
  topicsById,
}: {
  topic: LearningTopic;
  topicsById: ReadonlyMap<string, LearningTopic>;
}) {
  const qc = useQueryClient();
  // Savoli bor mavzuda avval borlari ko'rinadi; bo'sh mavzuda — biriktirish uchun mavzusizlar.
  const [scope, setScope] = useState<QuestionScope>(topic.questionCount > 0 ? 'linked' : 'unlinked');
  const [search, setSearch] = useState('');
  const [selection, setSelection] = useState<Selection>(EMPTY_SELECTION);
  const q = useDebouncedValue(search.trim(), SEARCH_DEBOUNCE_MS);

  const list = useInfiniteQuery({
    queryKey: learningKeys.topicQuestions(topic.id, scope, q),
    queryFn: ({ pageParam }) =>
      fetchQuestionsPage(
        learningQuestionsApi.list,
        { subject: topic.subject, topicId: topic.id, scope, q },
        pageParam,
      ),
    initialPageParam: 1,
    getNextPageParam: (last) => last.nextPage ?? undefined,
  });

  const questions = useMemo(() => flattenPages(list.data?.pages ?? []), [list.data]);
  const total = list.data?.pages[0]?.total ?? null;

  const link = useMutation({
    mutationFn: (ids: string[]) => learningTopicsApi.linkQuestions(topic.id, ids),
    onSuccess: (_data, ids) => {
      toast.success(`${ids.length} ta savol "${topic.title.uz}" mavzusiga biriktirildi`);
      setSelection(EMPTY_SELECTION);
      // Savollar soni va "Mavzusiz" ro'yxati yangilansin.
      void qc.invalidateQueries({ queryKey: learningKeys.topics });
      void qc.invalidateQueries({ queryKey: learningKeys.questions });
    },
    onError: (err) => toast.error(topicErrorMessage(err)),
  });

  const selectableVisible = questions.filter((qn) => isSelectable(qn, topic.id));
  const allVisibleSelected =
    selectableVisible.length > 0 && selectableVisible.every((qn) => selection.has(qn.id));
  const moved = countMoved(selection, topic.id);

  return (
    <>
      <SheetHeader className="pr-12">
        <SheetTitle>Savollar: {topic.title.uz}</SheetTitle>
        <SheetDescription>
          {subjectLabel(topic.subject)}, {gradeRangeLabel(topic.minGrade, topic.maxGrade)}. Hozir{' '}
          <strong className={topic.questionCount < MIN_TOPIC_QUESTIONS ? WARNING_TEXT : undefined}>
            {topic.questionCount}
          </strong>{' '}
          ta faol savol biriktirilgan (kamida {MIN_TOPIC_QUESTIONS} ta kerak).
        </SheetDescription>
      </SheetHeader>

      <div className="space-y-3 border-b border-border px-6 py-4">
        <ScopeSwitch value={scope} onChange={setScope} />
        <Input
          icon={<Search />}
          placeholder="Savol matni yoki ID..."
          aria-label="Savollarni qidirish"
          value={search}
          maxLength={100}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto px-6 py-4">
        <QuestionList
          topic={topic}
          topicsById={topicsById}
          questions={questions}
          selection={selection}
          isLoading={list.isLoading}
          error={list.isError ? list.error : null}
          onRetry={() => void list.refetch()}
          allVisibleSelected={allVisibleSelected}
          canSelectAny={selectableVisible.length > 0}
          onToggleAll={() => setSelection((s) => toggleAllVisible(s, questions, topic.id))}
          onToggle={(qn) => setSelection((s) => toggleSelected(s, qn))}
        />

        {list.hasNextPage && (
          <div className="mt-4 flex justify-center">
            <Button
              variant="outline"
              loading={list.isFetchingNextPage}
              onClick={() => void list.fetchNextPage()}
            >
              Yana yuklash
            </Button>
          </div>
        )}
        {!list.isLoading && questions.length > 0 && (
          <p className="mt-3 text-center text-xs text-muted-foreground" aria-live="polite">
            {total !== null
              ? `Jami ${total} ta, ${questions.length} tasi yuklandi`
              : `${questions.length} ta mavzusiz savol yuklandi${list.hasNextPage ? ' (yana bor)' : ''}`}
          </p>
        )}
      </div>

      <SheetFooter className="items-center sm:justify-between">
        <div className="text-xs text-muted-foreground" aria-live="polite">
          <p>Tanlangan: <strong className="text-foreground">{selection.size}</strong></p>
          {moved > 0 && (
            <p className={cn('mt-0.5', WARNING_TEXT)}>
              {moved} tasi boshqa mavzudan bu mavzuga ko&apos;chiriladi.
            </p>
          )}
        </div>
        <Button
          disabled={selection.size === 0 || link.isPending}
          onClick={() => link.mutate([...selection.keys()])}
        >
          {link.isPending ? <Loader2 className="animate-spin" /> : <Link2 />}
          Mavzuga biriktirish{selection.size > 0 ? ` (${selection.size})` : ''}
        </Button>
      </SheetFooter>
    </>
  );
}

/* ─── Rejim almashtirgich ─── */

function ScopeSwitch({
  value,
  onChange,
}: {
  value: QuestionScope;
  onChange: (scope: QuestionScope) => void;
}) {
  return (
    <div
      role="group"
      aria-label="Qaysi savollar ko'rsatilsin"
      className="inline-flex max-w-full rounded-lg bg-muted p-1"
    >
      {QUESTION_SCOPES.map((scope) => (
        <button
          key={scope.value}
          type="button"
          aria-pressed={value === scope.value}
          onClick={() => onChange(scope.value)}
          className={cn(
            'rounded-md px-3 py-1.5 text-sm font-medium text-muted-foreground transition-colors',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
            value === scope.value && 'bg-card text-foreground shadow-soft',
          )}
        >
          {scope.label}
        </button>
      ))}
    </div>
  );
}

/* ─── Savollar ro'yxati ─── */

function QuestionList({
  topic,
  topicsById,
  questions,
  selection,
  isLoading,
  error,
  onRetry,
  allVisibleSelected,
  canSelectAny,
  onToggleAll,
  onToggle,
}: {
  topic: LearningTopic;
  topicsById: ReadonlyMap<string, LearningTopic>;
  questions: LearningQuestion[];
  selection: Selection;
  isLoading: boolean;
  error: unknown;
  onRetry: () => void;
  allVisibleSelected: boolean;
  canSelectAny: boolean;
  onToggleAll: () => void;
  onToggle: (question: LearningQuestion) => void;
}) {
  if (isLoading) {
    return (
      <div className="space-y-2" aria-busy>
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton key={i} className="h-16 w-full rounded-lg" />
        ))}
      </div>
    );
  }
  if (error && questions.length === 0) {
    return (
      <EmptyState
        icon={<AlertTriangle />}
        title="Savollarni yuklab bo'lmadi"
        description={topicErrorMessage(error)}
        action={<Button variant="outline" onClick={onRetry}>Qayta urinish</Button>}
      />
    );
  }
  if (questions.length === 0) {
    return (
      <EmptyState
        title="Savol topilmadi"
        description="Bu filtrda savol yo'q. Boshqa rejimni tanlang yoki qidiruvni o'zgartiring."
      />
    );
  }
  return (
    <>
      <div className="mb-3 flex items-center gap-2">
        <Checkbox
          id="lq-select-all"
          checked={allVisibleSelected}
          disabled={!canSelectAny}
          onCheckedChange={onToggleAll}
        />
        <Label htmlFor="lq-select-all" className="cursor-pointer">
          Ko&apos;rinib turganlarning hammasini tanlash
        </Label>
      </div>
      <ul className="space-y-2">
        {questions.map((question) => (
          <QuestionItem
            key={question.id}
            question={question}
            topic={topic}
            topicsById={topicsById}
            checked={selection.has(question.id)}
            onToggle={() => onToggle(question)}
          />
        ))}
      </ul>
    </>
  );
}

function questionText(question: LearningQuestion): string {
  return question.prompt.uz || question.prompt.ru || question.prompt.en || '—';
}

function QuestionItem({
  question,
  topic,
  topicsById,
  checked,
  onToggle,
}: {
  question: LearningQuestion;
  topic: LearningTopic;
  topicsById: ReadonlyMap<string, LearningTopic>;
  checked: boolean;
  onToggle: () => void;
}) {
  const selectable = isSelectable(question, topic.id);
  const inputId = `lq-${question.id}`;

  return (
    <li>
      <label
        htmlFor={inputId}
        className={cn(
          'flex items-start gap-3 rounded-lg border border-border p-3 transition-colors',
          selectable ? 'cursor-pointer hover:bg-accent/40' : 'bg-muted/30',
          checked && 'border-primary/50 bg-primary/5',
        )}
      >
        <Checkbox
          id={inputId}
          className="mt-0.5"
          checked={checked}
          disabled={!selectable}
          onCheckedChange={onToggle}
        />
        <div className="min-w-0 flex-1">
          <p className="line-clamp-2 text-sm font-medium">{questionText(question)}</p>
          <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
            {question.externalId && (
              <span className="font-mono text-2xs text-muted-foreground">{question.externalId}</span>
            )}
            <Badge variant="info" size="sm">
              {gradeRangeLabel(question.minGrade, question.maxGrade)}
            </Badge>
            {question.status !== 'ACTIVE' && (
              <Badge variant="secondary" size="sm">{QUESTION_STATUS_LABELS[question.status]}</Badge>
            )}
            {!overlapsGrades(question, topic) && (
              <Badge
                variant="warning"
                size="sm"
                className={WARNING_BADGE}
                title="Savol sinflari mavzu sinflariga to'g'ri kelmaydi"
              >
                <AlertTriangle className="h-3 w-3" aria-hidden /> Sinf mos emas
              </Badge>
            )}
            <TopicBadge question={question} topic={topic} topicsById={topicsById} />
          </div>
        </div>
      </label>
    </li>
  );
}

function TopicBadge({
  question,
  topic,
  topicsById,
}: {
  question: LearningQuestion;
  topic: LearningTopic;
  topicsById: ReadonlyMap<string, LearningTopic>;
}) {
  if (question.topicId === null) {
    return <Badge variant="outline" size="sm">Mavzusiz</Badge>;
  }
  if (question.topicId === topic.id) {
    return <Badge variant="success" size="sm">Shu mavzuda</Badge>;
  }
  const other = topicsById.get(question.topicId)?.title.uz ?? "noma'lum mavzu";
  return <Badge variant="secondary" size="sm">Boshqa mavzuda: {other}</Badge>;
}
