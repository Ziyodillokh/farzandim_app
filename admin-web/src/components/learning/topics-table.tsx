'use client';

import { useEffect, useRef } from 'react';
import {
  AlertTriangle,
  ArrowDown,
  ArrowUp,
  Eye,
  EyeOff,
  ListChecks,
  Pencil,
  Plus,
  Route,
} from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/common/empty-state';
import {
  MIN_TOPIC_QUESTIONS,
  TOPIC_STATUS_LABELS,
  gradeRangeLabel,
} from '@/lib/constants/learning';
import { cn } from '@/lib/utils';
import type { LearningTopic } from '@/types/api.types';
import { topicErrorMessage } from './topic-errors';
import { isUnderfilled, type MoveDirection } from './topic-order';
import { WARNING_BADGE } from './warning-styles';

const COLUMN_COUNT = 7;

const moveButtonId = (topicId: string, direction: MoveDirection) =>
  `topic-move-${direction === -1 ? 'up' : 'down'}-${topicId}`;

export interface TopicsTableProps {
  /** Tanlangan fan mavzulari, tartiblangan. */
  topics: LearningTopic[];
  isLoading: boolean;
  isFetching: boolean;
  error: unknown;
  /** Tartib saqlanayotgan vaqtda yangi ko'chirishlar qabul qilinmaydi. */
  isReordering: boolean;
  /** Biror mavzuning holati almashtirilmoqda — boshqa almashtirishlar qabul qilinmaydi. */
  isToggling: boolean;
  onRetry: () => void;
  onCreate: () => void;
  onEdit: (topic: LearningTopic) => void;
  onOpenQuestions: (topic: LearningTopic) => void;
  onMove: (topic: LearningTopic, direction: MoveDirection) => void;
  onToggleStatus: (topic: LearningTopic) => void;
}

export function TopicsTable(props: TopicsTableProps) {
  const { topics, isLoading, isFetching, error, isReordering, onMove } = props;
  const pendingFocus = useRef<string | null>(null);
  const orderKey = topics.map((t) => t.id).join(',');

  // Qator ko'chganda brauzer fokusni yo'qotishi mumkin — ko'chirilgan
  // qatorning o'sha tugmasiga qaytaramiz (klaviatura bilan ketma-ket ko'chirish uchun).
  useEffect(() => {
    const id = pendingFocus.current;
    if (!id) return;
    pendingFocus.current = null;
    document.getElementById(id)?.focus();
  }, [orderKey]);

  const handleMove = (topic: LearningTopic, direction: MoveDirection) => {
    if (isReordering) return;
    pendingFocus.current = moveButtonId(topic.id, direction);
    onMove(topic, direction);
  };

  return (
    <Card className="overflow-hidden">
      {/* Yangilash xatosi: eski qatorlar ko'rinib tursa ham ogohlantiramiz. */}
      {Boolean(error) && topics.length > 0 && (
        <p
          role="alert"
          className="flex items-center gap-2 border-b border-destructive/30 bg-destructive/10 px-4 py-2 text-xs text-destructive"
        >
          <AlertTriangle className="h-3.5 w-3.5 shrink-0" aria-hidden />
          Ro&apos;yxatni yangilab bo&apos;lmadi — eski ma&apos;lumot ko&apos;rsatilmoqda:{' '}
          {topicErrorMessage(error)}
        </p>
      )}
      {/* Tor ekranda jadval karta ichida gorizontal suriladi */}
      <div className="overflow-x-auto">
        <table className="w-full min-w-[1040px] text-sm" aria-busy={isFetching || isReordering}>
          <caption className="sr-only">
            Tanlangan fan mavzulari bola ilovasidagi yo&apos;l tartibida
          </caption>
          <thead>
            <tr className="border-b border-border bg-muted/30 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <th scope="col" className="w-[120px] px-4 py-3 text-left">Tartib</th>
              <th scope="col" className="px-4 py-3 text-left">Mavzu</th>
              <th scope="col" className="px-4 py-3 text-left">Kalit</th>
              <th scope="col" className="px-4 py-3 text-left">Sinflar</th>
              <th scope="col" className="px-4 py-3 text-left">Savollar</th>
              <th scope="col" className="px-4 py-3 text-left">Holat</th>
              <th scope="col" className="px-4 py-3 text-right">Amallar</th>
            </tr>
          </thead>
          <tbody className={cn(isFetching && !isLoading && 'opacity-70 transition-opacity')}>
            <TableBody {...props} onMove={handleMove} />
          </tbody>
        </table>
      </div>
    </Card>
  );
}

function TableBody(props: TopicsTableProps) {
  const { topics, isLoading, error, onRetry, onCreate } = props;

  if (isLoading) {
    return Array.from({ length: 6 }).map((_, i) => <RowSkeleton key={i} />);
  }
  if (Boolean(error) && topics.length === 0) {
    return (
      <EmptyRow>
        <EmptyState
          icon={<AlertTriangle />}
          title="Mavzularni yuklab bo'lmadi"
          description={topicErrorMessage(error)}
          action={<Button variant="outline" onClick={onRetry}>Qayta urinish</Button>}
        />
      </EmptyRow>
    );
  }
  if (topics.length === 0) {
    return (
      <EmptyRow>
        <EmptyState
          icon={<Route />}
          title="Bu fanda hali mavzu yo'q"
          description="Mavzu yarating, so'ng unga kamida 10 ta faol savol biriktiring — shundan keyin bola ilovasida chiqadi."
          action={
            <Button onClick={onCreate}>
              <Plus className="h-4 w-4" /> Yangi mavzu
            </Button>
          }
        />
      </EmptyRow>
    );
  }
  return topics.map((topic, index) => (
    <TopicRow
      key={topic.id}
      topic={topic}
      index={index}
      isFirst={index === 0}
      isLast={index === topics.length - 1}
      {...props}
    />
  ));
}

const EmptyRow = ({ children }: { children: React.ReactNode }) => (
  <tr>
    <td colSpan={COLUMN_COUNT} className="p-0">
      {children}
    </td>
  </tr>
);

/* ─── Mavzu qatori ─── */

function TopicRow({
  topic,
  index,
  isFirst,
  isLast,
  isReordering,
  isToggling,
  onEdit,
  onOpenQuestions,
  onMove,
  onToggleStatus,
}: TopicsTableProps & { topic: LearningTopic; index: number; isFirst: boolean; isLast: boolean }) {
  const isHidden = topic.status === 'HIDDEN';
  const title = topic.title.uz;

  return (
    <tr className="border-b border-border last:border-0 transition-colors hover:bg-accent/30">
      <td className="px-4 py-3">
        <div className="flex items-center gap-1">
          <span className="w-6 text-center font-semibold tabular-nums text-muted-foreground">
            {index + 1}
          </span>
          <MoveButton
            topic={topic}
            direction={-1}
            disabled={isFirst}
            isBusy={isReordering}
            label={`"${title}" mavzusini yuqoriga ko'chirish`}
            onMove={onMove}
          />
          <MoveButton
            topic={topic}
            direction={1}
            disabled={isLast}
            isBusy={isReordering}
            label={`"${title}" mavzusini pastga ko'chirish`}
            onMove={onMove}
          />
        </div>
      </td>
      <td className="px-4 py-3">
        <div className={cn('min-w-[220px] max-w-[360px]', isHidden && 'opacity-70')}>
          <p className="font-medium">{title}</p>
          {topic.goal?.uz && (
            <p className="mt-0.5 line-clamp-1 text-xs text-muted-foreground">{topic.goal.uz}</p>
          )}
          <div className="mt-1 flex gap-1">
            {topic.title.ru && <Badge variant="outline" size="sm">RU</Badge>}
            {topic.title.en && <Badge variant="outline" size="sm">EN</Badge>}
          </div>
        </div>
      </td>
      <td className="whitespace-nowrap px-4 py-3 font-mono text-xs text-muted-foreground">
        {topic.key}
      </td>
      <td className="whitespace-nowrap px-4 py-3">
        <Badge variant="info" size="sm">{gradeRangeLabel(topic.minGrade, topic.maxGrade)}</Badge>
      </td>
      <td className="px-4 py-3">
        <QuestionCount count={topic.questionCount} />
      </td>
      <td className="whitespace-nowrap px-4 py-3">
        <Badge variant={isHidden ? 'secondary' : 'success'} size="sm">
          {TOPIC_STATUS_LABELS[topic.status]}
        </Badge>
      </td>
      <td className="whitespace-nowrap px-4 py-3">
        <div className="flex items-center justify-end gap-1">
          <Button
            variant="outline"
            size="sm"
            aria-label={`Savollar: "${title}" mavzusi`}
            onClick={() => onOpenQuestions(topic)}
          >
            <ListChecks /> Savollar
          </Button>
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => onEdit(topic)}
            aria-label={`"${title}" mavzusini tahrirlash`}
            title="Tahrirlash"
          >
            <Pencil />
          </Button>
          {/* aria-disabled (disabled emas): almashtirish ketayotganda fokus yo'qolmaydi. */}
          <Button
            variant="ghost"
            size="sm"
            aria-disabled={isToggling || undefined}
            className="aria-disabled:cursor-not-allowed aria-disabled:opacity-50 aria-disabled:hover:bg-transparent"
            onClick={() => {
              if (!isToggling) onToggleStatus(topic);
            }}
            aria-label={
              isHidden ? `"${title}" mavzusini ko'rsatish` : `"${title}" mavzusini yashirish`
            }
          >
            {isHidden ? <Eye /> : <EyeOff />}
            {isHidden ? "Ko'rsatish" : 'Yashirish'}
          </Button>
        </div>
      </td>
    </tr>
  );
}

/**
 * Ko'chirish tugmasi. Chekkada va saqlash ketayotganda `disabled` emas,
 * `aria-disabled`: tugma fokusda qoladi (ketma-ket bosganda fokus
 * yo'qolmaydi), bosish esa hech narsa qilmaydi.
 */
function MoveButton({
  topic,
  direction,
  disabled,
  isBusy,
  label,
  onMove,
}: {
  topic: LearningTopic;
  direction: MoveDirection;
  /** Chekkada: bu yo'nalishda ko'chirib bo'lmaydi. */
  disabled: boolean;
  /** Tartib saqlanayotgan (yoki yangilanayotgan) payt. */
  isBusy: boolean;
  label: string;
  onMove: (topic: LearningTopic, direction: MoveDirection) => void;
}) {
  return (
    <Button
      id={moveButtonId(topic.id, direction)}
      type="button"
      variant="ghost"
      size="icon-sm"
      aria-label={label}
      aria-disabled={disabled || isBusy || undefined}
      title={direction === -1 ? 'Yuqoriga' : 'Pastga'}
      className="aria-disabled:cursor-not-allowed aria-disabled:opacity-40 aria-disabled:hover:bg-transparent"
      onClick={() => {
        if (!disabled && !isBusy) onMove(topic, direction);
      }}
    >
      {direction === -1 ? <ArrowUp /> : <ArrowDown />}
    </Button>
  );
}

/** Savollar soni; `MIN_TOPIC_QUESTIONS`dan kam bo'lsa ogohlantirish. */
function QuestionCount({ count }: { count: number }) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className="font-semibold tabular-nums">
        {count}
        <span className="sr-only"> ta faol savol</span>
      </span>
      {isUnderfilled({ questionCount: count }) && (
        <Badge
          variant="warning"
          size="sm"
          className={WARNING_BADGE}
          title={`Bolaga taklif qilinishi uchun kamida ${MIN_TOPIC_QUESTIONS} ta faol savol kerak`}
        >
          <AlertTriangle className="h-3 w-3" aria-hidden />
          {MIN_TOPIC_QUESTIONS} tadan kam
        </Badge>
      )}
    </div>
  );
}

/* ─── Qator skeleti ─── */

function RowSkeleton() {
  return (
    <tr className="border-b border-border">
      <td className="px-4 py-3"><Skeleton className="h-6 w-20" /></td>
      <td className="px-4 py-3">
        <div className="space-y-1.5">
          <Skeleton className="h-3 w-52" />
          <Skeleton className="h-3 w-32" />
        </div>
      </td>
      <td className="px-4 py-3"><Skeleton className="h-3 w-28" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-16 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-24 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="h-5 w-14 rounded-full" /></td>
      <td className="px-4 py-3"><Skeleton className="ml-auto h-8 w-40" /></td>
    </tr>
  );
}
