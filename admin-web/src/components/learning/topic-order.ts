/**
 * Mavzular ro'yxati ustida sof (React'siz) amallar: tartiblash, ko'chirish,
 * optimistik kesh yangilash va fanlar bo'yicha xulosa. Hammasi o'zgarmas —
 * kirish ro'yxatiga tegmaydi, yangi nusxa qaytaradi.
 */
import { MIN_TOPIC_QUESTIONS } from '@/lib/constants/learning';
import type { LearningSubject, LearningTopic, LearningTopicStatus } from '@/types/api.types';

export type MoveDirection = -1 | 1;

/** Backend tartibi: `position`, teng bo'lsa yaratilgan vaqt, keyin id (barqaror). */
export function sortTopics(topics: readonly LearningTopic[]): LearningTopic[] {
  return [...topics].sort(
    (a, b) =>
      a.position - b.position ||
      a.createdAt.localeCompare(b.createdAt) ||
      a.id.localeCompare(b.id),
  );
}

export function topicsOfSubject(
  topics: readonly LearningTopic[],
  subject: LearningSubject,
): LearningTopic[] {
  return sortTopics(topics.filter((t) => t.subject === subject));
}

/** Mavzu bolaga taklif qilinishi uchun faol savollari yetarli emas. */
export const isUnderfilled = (topic: Pick<LearningTopic, 'questionCount'>): boolean =>
  topic.questionCount < MIN_TOPIC_QUESTIONS;

/**
 * `id`ni bir o'ringa yuqoriga (-1) yoki pastga (1) ko'chiradi. Ko'chirib
 * bo'lmasa (chekka yoki id yo'q) `null`.
 */
export function moveId(
  ids: readonly string[],
  id: string,
  direction: MoveDirection,
): string[] | null {
  const from = ids.indexOf(id);
  const to = from + direction;
  if (from === -1 || to < 0 || to >= ids.length) return null;
  const next = [...ids];
  [next[from], next[to]] = [next[to]!, next[from]!];
  return next;
}

/**
 * Fan mavzularini `orderedIds` tartibiga keltiradi (optimistik yangilash).
 * `position = boshlang'ich + indeks`, boshlang'ich — fandagi eng kichik joriy
 * position (backend 0 yoki 1 dan boshlashini faraz qilmaymiz). Ro'yxatda
 * ko'rsatilmagan mavzular oxirida joriy tartibda qoladi; boshqa fanlarga tegilmaydi.
 */
export function applyOrder(
  topics: readonly LearningTopic[],
  subject: LearningSubject,
  orderedIds: readonly string[],
): LearningTopic[] {
  const current = topicsOfSubject(topics, subject);
  if (current.length === 0) return [...topics];
  const base = Math.min(...current.map((t) => t.position));
  const known = new Set(current.map((t) => t.id));
  const requested = orderedIds.filter((id) => known.has(id));
  const rest = current.map((t) => t.id).filter((id) => !requested.includes(id));
  const positions = new Map([...requested, ...rest].map((id, index) => [id, base + index]));
  return topics.map((t) =>
    positions.has(t.id) && positions.get(t.id) !== t.position
      ? { ...t, position: positions.get(t.id)! }
      : t,
  );
}

/**
 * Xatoda orqaga qaytarish: faqat `position`lar snapshotdagidek bo'ladi —
 * shu orada boshqa o'zgarish (masalan, holat almashtirish) buzilmaydi.
 */
export function restorePositions(
  current: readonly LearningTopic[],
  snapshot: readonly LearningTopic[],
): LearningTopic[] {
  const positions = new Map(snapshot.map((t) => [t.id, t.position]));
  return current.map((t) =>
    positions.has(t.id) && positions.get(t.id) !== t.position
      ? { ...t, position: positions.get(t.id)! }
      : t,
  );
}

/** Keshda bitta mavzu holatini almashtirish (boshqa qatorlarga tegmaydi). */
export function setStatusInList(
  topics: readonly LearningTopic[],
  id: string,
  status: LearningTopicStatus,
): LearningTopic[] {
  return topics.map((t) => (t.id === id && t.status !== status ? { ...t, status } : t));
}

export interface SubjectSummary {
  total: number;
  /**
   * Ko'rsatilgan (ACTIVE) mavzulardan faol savollari `MIN_TOPIC_QUESTIONS`dan
   * kamlari — bola ularni ko'ra olmaydi. Yashirin mavzular qoralama sanaladi.
   */
  underfilled: number;
}

/** Fan tablari uchun: nechta mavzu va nechtasida savol yetishmaydi. */
export function summarizeBySubject(
  topics: readonly LearningTopic[],
): Partial<Record<LearningSubject, SubjectSummary>> {
  return topics.reduce<Partial<Record<LearningSubject, SubjectSummary>>>((acc, topic) => {
    const prev = acc[topic.subject] ?? { total: 0, underfilled: 0 };
    return {
      ...acc,
      [topic.subject]: {
        total: prev.total + 1,
        underfilled: prev.underfilled + (topic.status === 'ACTIVE' && isUnderfilled(topic) ? 1 : 0),
      },
    };
  }, {});
}
