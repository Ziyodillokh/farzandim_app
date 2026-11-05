'use client';

/**
 * Kunlik o'quv — mavzular katalogi (fan bo'yicha o'quv dasturi).
 * Bola ilovasi fan mavzularini shu tartibda "yo'l" ko'rinishida ko'rsatadi.
 * O'chirish yo'q: yashirish yumshoq o'chirish o'rnini bosadi.
 */

import { useMemo, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent } from '@/components/ui/tabs';
import { PageHeader } from '@/components/common/page-header';
import { learningTopicsApi } from '@/lib/api/admin.api';
import {
  DEFAULT_LEARNING_SUBJECT,
  MIN_TOPIC_QUESTIONS,
  isLearningSubject,
} from '@/lib/constants/learning';
import type { LearningSubject, LearningTopic } from '@/types/api.types';
import { SubjectTabs } from '@/components/learning/subject-tabs';
import { TopicFormDialog, type TopicFormTarget } from '@/components/learning/topic-form-dialog';
import { learningKeys } from '@/components/learning/topic-keys';
import {
  moveId,
  summarizeBySubject,
  topicsOfSubject,
  type MoveDirection,
} from '@/components/learning/topic-order';
import { TopicQuestionsSheet } from '@/components/learning/topic-questions-sheet';
import { TopicsTable } from '@/components/learning/topics-table';
import { useReorderTopics, useToggleTopicStatus } from '@/components/learning/use-topic-mutations';

const NO_TOPICS: LearningTopic[] = [];

export default function LearningTopicsPage() {
  const [subject, setSubject] = useState<LearningSubject>(DEFAULT_LEARNING_SUBJECT);
  // `null` — oyna/panel yopiq.
  const [formTarget, setFormTarget] = useState<TopicFormTarget | null>(null);
  const [questionsTopicId, setQuestionsTopicId] = useState<string | null>(null);
  // Ekran o'quvchi uchun: ko'chirish natijasi.
  const [announcement, setAnnouncement] = useState('');
  // Oyna/panel yopilganda fokus shu tugmaga qaytadi (klaviatura foydalanuvchisi joyini yo'qotmasin).
  const openerRef = useRef<HTMLElement | null>(null);
  const createButtonRef = useRef<HTMLButtonElement>(null);

  const topics = useQuery({
    queryKey: learningKeys.topics,
    queryFn: () => learningTopicsApi.list(),
  });
  const reorder = useReorderTopics();
  const toggleStatus = useToggleTopicStatus();

  const allTopics = topics.data ?? NO_TOPICS;
  const summaries = useMemo(() => summarizeBySubject(allTopics), [allTopics]);
  const subjectTopics = useMemo(() => topicsOfSubject(allTopics, subject), [allTopics, subject]);
  const topicsById = useMemo(() => new Map(allTopics.map((t) => [t.id, t])), [allTopics]);
  // Panel har doim eng so'nggi mavzu ma'lumotini (savollar soni) ko'rsatadi.
  const questionsTopic = questionsTopicId ? (topicsById.get(questionsTopicId) ?? null) : null;

  const handleMove = (topic: LearningTopic, direction: MoveDirection) => {
    const next = moveId(
      subjectTopics.map((t) => t.id),
      topic.id,
      direction,
    );
    if (!next) return;
    reorder.mutate({ subject, ids: next });
    setAnnouncement(`"${topic.title.uz}" ${next.indexOf(topic.id) + 1}-o'ringa ko'chirildi`);
  };

  const handleToggleStatus = (topic: LearningTopic) =>
    toggleStatus.mutate({ topic, status: topic.status === 'ACTIVE' ? 'HIDDEN' : 'ACTIVE' });

  const rememberOpener = () => {
    const active = document.activeElement;
    openerRef.current = active instanceof HTMLElement && active !== document.body ? active : null;
  };

  /** Radix fokusni tetikchiga qaytaradi, bizda tetikchi yo'q — ochgan tugmaga qaytaramiz. */
  const restoreFocus = (event: Event) => {
    event.preventDefault();
    const opener = openerRef.current;
    // Ochgan tugma yo'qolgan bo'lishi mumkin (masalan, bo'sh holatdagi "Yangi mavzu").
    (opener?.isConnected ? opener : createButtonRef.current)?.focus();
    openerRef.current = null;
  };

  const openCreate = () => {
    rememberOpener();
    setFormTarget({ mode: 'create', subject });
  };
  const openEdit = (topic: LearningTopic) => {
    rememberOpener();
    setFormTarget({ mode: 'edit', topic });
  };
  const openQuestions = (topic: LearningTopic) => {
    rememberOpener();
    setQuestionsTopicId(topic.id);
  };

  return (
    <div className="container mx-auto max-w-screen-2xl px-4 py-6 sm:px-6 sm:py-8">
      <PageHeader
        eyebrow="Kunlik o'quv — bola ilovasidagi fan yo'li"
        title="Mavzular"
        count={topics.data ? subjectTopics.length : undefined}
        actions={
          <Button ref={createButtonRef} onClick={openCreate}>
            <Plus className="h-4 w-4" /> Yangi mavzu
          </Button>
        }
      />

      <p className="mb-4 max-w-3xl text-sm text-muted-foreground">
        Jadvaldagi tartib bola ilovasidagi yo&apos;l tartibidir. Mavzu bolaga kamida{' '}
        {MIN_TOPIC_QUESTIONS} ta faol savol bo&apos;lgandagina taklif qilinadi.
      </p>

      <Tabs
        value={subject}
        onValueChange={(value) => isLearningSubject(value) && setSubject(value)}
      >
        <SubjectTabs summaries={summaries} />
        <TabsContent value={subject} className="mt-0">
          <TopicsTable
            topics={subjectTopics}
            isLoading={topics.isLoading}
            isFetching={topics.isFetching}
            error={topics.isError ? topics.error : null}
            isReordering={reorder.isPending}
            isToggling={toggleStatus.isPending}
            onRetry={() => void topics.refetch()}
            onCreate={openCreate}
            onEdit={openEdit}
            onOpenQuestions={openQuestions}
            onMove={handleMove}
            onToggleStatus={handleToggleStatus}
          />
        </TabsContent>
      </Tabs>

      <p role="status" aria-live="polite" className="sr-only">
        {reorder.isPending ? `${announcement} Saqlanmoqda…` : announcement}
      </p>

      <TopicFormDialog
        target={formTarget}
        onOpenChange={(open) => !open && setFormTarget(null)}
        onCloseAutoFocus={restoreFocus}
      />

      <TopicQuestionsSheet
        topic={questionsTopic}
        topicsById={topicsById}
        onOpenChange={(open) => !open && setQuestionsTopicId(null)}
        onCloseAutoFocus={restoreFocus}
      />
    </div>
  );
}
