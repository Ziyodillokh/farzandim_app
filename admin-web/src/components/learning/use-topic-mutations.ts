import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import {
  learningTopicsApi,
  type LearningTopicReorderPayload,
} from '@/lib/api/admin.api';
import type { LearningTopic, LearningTopicStatus } from '@/types/api.types';
import { topicErrorMessage } from './topic-errors';
import { learningKeys } from './topic-keys';
import { applyOrder, restorePositions, setStatusInList } from './topic-order';

interface ReorderContext {
  /** Optimistik yangilashdan oldingi holat (xatoda tartib shundan tiklanadi). */
  previous: LearningTopic[] | undefined;
}

/**
 * Tartibni saqlash — optimistik: ro'yxat darhol yangi tartibda ko'rinadi,
 * xato bo'lsa FAQAT `position`lar oldingi holatga qaytadi (shu orada boshqa
 * o'zgarish, masalan holat almashtirish, buzilmaydi) va xato ko'rsatiladi.
 */
export function useReorderTopics() {
  const qc = useQueryClient();

  return useMutation<void, unknown, LearningTopicReorderPayload, ReorderContext>({
    mutationFn: (payload) => learningTopicsApi.reorder(payload),
    onMutate: async ({ subject, ids }) => {
      await qc.cancelQueries({ queryKey: learningKeys.topics });
      const previous = qc.getQueryData<LearningTopic[]>(learningKeys.topics);
      qc.setQueryData<LearningTopic[]>(learningKeys.topics, (old) =>
        old ? applyOrder(old, subject, ids) : old,
      );
      return { previous };
    },
    onError: (err, _vars, context) => {
      const snapshot = context?.previous;
      if (snapshot) {
        qc.setQueryData<LearningTopic[]>(learningKeys.topics, (old) =>
          old ? restorePositions(old, snapshot) : old,
        );
      }
      toast.error(`Tartibni saqlab bo'lmadi, oldingi tartib tiklandi: ${topicErrorMessage(err)}`);
    },
    // Server haqiqatiga qaytamiz (muvaffaqiyatda ham, xatoda ham).
    onSettled: () => qc.invalidateQueries({ queryKey: learningKeys.topics }),
  });
}

interface ToggleVars {
  topic: Pick<LearningTopic, 'id' | 'status'>;
  status: LearningTopicStatus;
}

/**
 * Ko'rsatish / yashirish (o'chirish o'rniga) — optimistik; xatoda faqat shu
 * qator oldingi holatga qaytadi.
 */
export function useToggleTopicStatus() {
  const qc = useQueryClient();
  const setStatus = (id: string, status: LearningTopicStatus) =>
    qc.setQueryData<LearningTopic[]>(learningKeys.topics, (old) =>
      old ? setStatusInList(old, id, status) : old,
    );

  return useMutation<LearningTopic, unknown, ToggleVars>({
    mutationFn: ({ topic, status }) => learningTopicsApi.update(topic.id, { status }),
    onMutate: async ({ topic, status }) => {
      await qc.cancelQueries({ queryKey: learningKeys.topics });
      setStatus(topic.id, status);
    },
    onError: (err, { topic }) => {
      setStatus(topic.id, topic.status);
      toast.error(topicErrorMessage(err));
    },
    onSuccess: (_data, { status }) => {
      toast.success(
        status === 'HIDDEN'
          ? "Mavzu yashirildi — bolalar ilovasida ko'rinmaydi"
          : "Mavzu ko'rsatildi",
      );
    },
    onSettled: () => qc.invalidateQueries({ queryKey: learningKeys.topics }),
  });
}
