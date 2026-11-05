/**
 * Mavzu "Savollar" panelining sof mantiqi: filtr rejimi → API so'rovi, sahifalash
 * va tanlov. React yoki tarmoqsiz — `fetchPage` tashqaridan beriladi.
 *
 * Kontraktda faqat `topicId` filtri bor ("mavzusiz" filtri yo'q), shuning uchun
 * "Mavzusiz" rejimi fan savollarini sahifalab o'qib, `topicId === null` larni
 * mijozda ajratadi.
 */
import type { LearningQuestionListParams } from '@/lib/api/admin.api';
import type { LearningQuestion, LearningSubject, LearningTopic, Paginated } from '@/types/api.types';

export type QuestionScope = 'linked' | 'unlinked' | 'all';

export const QUESTION_SCOPES: ReadonlyArray<{ value: QuestionScope; label: string }> = [
  { value: 'linked', label: 'Shu mavzudagi' },
  { value: 'unlinked', label: 'Mavzusiz' },
  { value: 'all', label: 'Barchasi' },
];

/** Ro'yxatda bir yuklashda ko'rsatiladigan savollar soni. */
export const QUESTION_PAGE_SIZE = 40;
/** Backend `limit` chegarasi — "Mavzusiz" rejimida shuncha bilan skanerlanadi. */
export const QUESTION_SCAN_LIMIT = 100;
/** "Mavzusiz" skanerida bir yuklashda ko'pi bilan nechta sahifa o'qiladi. */
export const MAX_SCAN_PAGES = 10;

export type FetchQuestions = (
  params: LearningQuestionListParams,
) => Promise<Paginated<LearningQuestion>>;

export interface QuestionsQuery {
  subject: LearningSubject;
  topicId: string;
  scope: QuestionScope;
  /** Qidiruv matni (allaqachon trim qilingan; bo'sh — qidiruvsiz). */
  q: string;
}

/** Bo'sh qiymatlar yuborilmaydi — backend `@IsIn`/`@IsString` bo'sh satrni rad etadi. */
export function toQuestionParams(
  query: QuestionsQuery,
  page: number,
  limit: number,
): LearningQuestionListParams {
  return {
    page,
    limit,
    subject: query.subject,
    ...(query.scope === 'linked' ? { topicId: query.topicId } : {}),
    ...(query.q ? { q: query.q } : {}),
  };
}

export interface QuestionsPage {
  items: LearningQuestion[];
  /** Keyingi yuklanadigan xom sahifa; `null` — ro'yxat tugagan. */
  nextPage: number | null;
  /** Aniq jami (faqat "Mavzusiz" rejimida noma'lum). */
  total: number | null;
}

/** Bitta so'rov — "Shu mavzudagi" va "Barchasi" rejimlari. */
async function fetchPlainPage(
  fetchPage: FetchQuestions,
  query: QuestionsQuery,
  page: number,
): Promise<QuestionsPage> {
  const result = await fetchPage(toQuestionParams(query, page, QUESTION_PAGE_SIZE));
  return {
    items: result.items,
    nextPage: page < result.totalPages ? page + 1 : null,
    total: result.total,
  };
}

/**
 * "Mavzusiz": sahifa-sahifa o'qib, `topicId === null` larni yig'adi — kamida
 * `QUESTION_PAGE_SIZE` ta bo'lguncha, ro'yxat tugaguncha yoki
 * `MAX_SCAN_PAGES` sahifaga yetguncha.
 */
async function fetchUnlinkedPage(
  fetchPage: FetchQuestions,
  query: QuestionsQuery,
  startPage: number,
): Promise<QuestionsPage> {
  let page = startPage;
  let scanned = 0;
  let items: LearningQuestion[] = [];
  let nextPage: number | null = page;
  while (nextPage !== null && scanned < MAX_SCAN_PAGES && items.length < QUESTION_PAGE_SIZE) {
    const result = await fetchPage(toQuestionParams(query, page, QUESTION_SCAN_LIMIT));
    items = [...items, ...result.items.filter((q) => q.topicId === null)];
    scanned += 1;
    nextPage = page < result.totalPages ? page + 1 : null;
    page += 1;
  }
  return { items, nextPage, total: null };
}

export function fetchQuestionsPage(
  fetchPage: FetchQuestions,
  query: QuestionsQuery,
  page: number,
): Promise<QuestionsPage> {
  return query.scope === 'unlinked'
    ? fetchUnlinkedPage(fetchPage, query, page)
    : fetchPlainPage(fetchPage, query, page);
}

/** Yuklangan sahifalarni bitta ro'yxatga birlashtiradi (takror id'siz). */
export function flattenPages(pages: ReadonlyArray<QuestionsPage>): LearningQuestion[] {
  const byId = new Map<string, LearningQuestion>();
  for (const question of pages.flatMap((p) => p.items)) {
    if (!byId.has(question.id)) byId.set(question.id, question);
  }
  return [...byId.values()];
}

/* ─── Tanlov (o'zgarmas) ─── */

/**
 * Tanlangan savollar: id → savol. Savolning o'zi saqlanadi, shuning uchun
 * qidiruv/rejim almashganda ham tanlov va "boshqa mavzudan ko'chiriladi"
 * hisobi to'g'ri qoladi.
 */
export type Selection = ReadonlyMap<string, LearningQuestion>;

export const EMPTY_SELECTION: Selection = new Map();

/** Mavzuga biriktirish mumkin: hali shu mavzuda emas. */
export const isSelectable = (question: LearningQuestion, topicId: string): boolean =>
  question.topicId !== topicId;

export function toggleSelected(selection: Selection, question: LearningQuestion): Selection {
  const next = new Map(selection);
  if (!next.delete(question.id)) next.set(question.id, question);
  return next;
}

/**
 * Ko'rinib turgan tanlanadigan savollarning hammasi tanlangan bo'lsa, ularni
 * olib tashlaydi; aks holda hammasini qo'shadi. Ko'rinmayotgan tanlovga tegmaydi.
 */
export function toggleAllVisible(
  selection: Selection,
  visible: readonly LearningQuestion[],
  topicId: string,
): Selection {
  const selectable = visible.filter((q) => isSelectable(q, topicId));
  const allSelected = selectable.length > 0 && selectable.every((q) => selection.has(q.id));
  const next = new Map(selection);
  selectable.forEach((q) => (allSelected ? next.delete(q.id) : next.set(q.id, q)));
  return next;
}

/** Tanlanganlar orasida boshqa mavzudan ko'chiriladiganlar soni. */
export function countMoved(selection: Selection, topicId: string): number {
  return [...selection.values()].filter((q) => q.topicId !== null && q.topicId !== topicId).length;
}

/**
 * Savol sinflari mavzu sinflari bilan kesishadimi. Kesishmasa savol shu
 * mavzuning hech bir sinfidagi bolaga chiqmaydi (10 ta qoidasida hisoblanmaydi).
 */
export const overlapsGrades = (
  question: Pick<LearningQuestion, 'minGrade' | 'maxGrade'>,
  topic: Pick<LearningTopic, 'minGrade' | 'maxGrade'>,
): boolean => question.minGrade <= topic.maxGrade && question.maxGrade >= topic.minGrade;
