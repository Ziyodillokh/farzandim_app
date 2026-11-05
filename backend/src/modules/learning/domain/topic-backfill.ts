// Eski erkin matnli mavzulardan (`learning_questions.topic.uz`) mavzular
// katalogini to'ldirish REJASI — sof funksiyalar (DB'siz). Skript
// (`scripts/learning/backfill-topics.ts`) shu rejani bajaradi.

import { LearningSubject } from '@prisma/client';
import { parseTopicText, TOPIC_KEY_MAX, TOPIC_TITLE_MAX, TopicText } from './topic-input';

const FALLBACK_KEY = 'topic';

const CYRILLIC: Readonly<Record<string, string>> = {
  а: 'a', б: 'b', в: 'v', г: 'g', д: 'd', е: 'e', ё: 'yo', ж: 'j', з: 'z', и: 'i',
  й: 'y', к: 'k', л: 'l', м: 'm', н: 'n', о: 'o', п: 'p', р: 'r', с: 's', т: 't',
  у: 'u', ф: 'f', х: 'x', ц: 'ts', ч: 'ch', ш: 'sh', щ: 'sh', ъ: '', ы: 'y', ь: '',
  э: 'e', ю: 'yu', я: 'ya', ў: 'o', қ: 'q', ғ: 'g', ҳ: 'h',
};

/** Guruhlash uchun: NFC, ortiqcha bo'shliqlarsiz, kichik harf. */
export function normalizeTopicName(value: string): string {
  return value.normalize('NFC').replace(/\s+/g, ' ').trim().toLowerCase();
}

/**
 * Sarlavhadan slug: kirill → lotin, oʻ / gʻ apostroflari tushiriladi
 * (`oʻzbek` → `ozbek`), diakritiklar olib tashlanadi. Hech qachon bo'sh emas.
 */
export function slugifyTopic(title: string): string {
  const latin = [...normalizeTopicName(title)].map((ch) => CYRILLIC[ch] ?? ch).join('');
  const slug = latin
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/[ʻʼ‘’`´']/gu, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return truncateKey(slug) || FALLBACK_KEY;
}

function truncateKey(key: string, max: number = TOPIC_KEY_MAX): string {
  return key.slice(0, max).replace(/-+$/g, '');
}

/** `base` band bo'lsa `base-2`, `base-3` … (80 belgidan oshmaydi). */
export function uniqueTopicKey(base: string, taken: ReadonlySet<string>): string {
  if (!taken.has(base)) return base;
  for (let n = 2; ; n++) {
    const suffix = `-${n}`;
    const candidate = `${truncateKey(base, TOPIC_KEY_MAX - suffix.length)}${suffix}`;
    if (!taken.has(candidate)) return candidate;
  }
}

export interface BackfillQuestion {
  id: string;
  externalId: string | null;
  subject: LearningSubject;
  /** Eski erkin matnli mavzu (`{uz, ru, en}` JSON). */
  topic: unknown;
  minGrade: number;
  maxGrade: number;
  isActive: boolean;
}

export interface BackfillExistingTopic {
  id: string;
  subject: LearningSubject;
  key: string;
  titleUz: string;
  position: number;
  /** Allaqachon bog'langan FAOL savollar soni. */
  activeQuestions: number;
}

export interface BackfillGroup {
  subject: LearningSubject;
  /** Mavjud mavzu (qayta ishlatiladi) yoki null — yangi yaratiladi. */
  existingTopicId: string | null;
  key: string;
  title: TopicText;
  minGrade: number;
  maxGrade: number;
  /** Faqat yangi mavzu uchun mazmunli; mavjudniki o'zgarmaydi. */
  position: number;
  questionIds: string[];
  /** Bog'lashdan keyingi faol savollar soni (mavjud + yangi). */
  activeQuestions: number;
}

export interface BackfillPlan {
  groups: BackfillGroup[];
  skipped: { questionId: string; reason: string }[];
}

interface Draft {
  nameKey: string;
  title: TopicText;
  minGrade: number;
  questions: BackfillQuestion[];
}

const compareText = (a: string, b: string): number => (a < b ? -1 : a > b ? 1 : 0);

/**
 * Mavzusiz savollarni (fan bo'yicha) normallashtirilgan `topic.uz` ga ko'ra
 * guruhlaydi. Mavjud mavzu (shu fan + shu normallashtirilgan nom) qayta
 * ishlatiladi; yangilari `(minGrade, title.uz)` tartibida mavjudlardan keyin
 * joylashadi. Kalit to'qnashsa — `-2`, `-3` qo'shimchasi.
 */
export function planTopicBackfill(
  questions: readonly BackfillQuestion[],
  existing: readonly BackfillExistingTopic[],
): BackfillPlan {
  const skipped: BackfillPlan['skipped'] = [];
  const bySubject = new Map<LearningSubject, BackfillQuestion[]>();
  for (const q of sortQuestions(questions)) {
    bySubject.set(q.subject, [...(bySubject.get(q.subject) ?? []), q]);
  }
  const groups = [...bySubject].flatMap(([subject, list]) =>
    planSubject(subject, list, existing.filter((t) => t.subject === subject), skipped),
  );
  return { groups, skipped };
}

function planSubject(
  subject: LearningSubject,
  questions: readonly BackfillQuestion[],
  existing: readonly BackfillExistingTopic[],
  skipped: BackfillPlan['skipped'],
): BackfillGroup[] {
  const existingByName = new Map(existing.map((t) => [normalizeTopicName(t.titleUz), t]));
  const takenKeys = new Set(existing.map((t) => t.key));
  let nextPosition = existing.reduce((max, t) => Math.max(max, t.position + 1), 0);

  return draftsOf(questions, skipped).map((draft) => {
    const reused = existingByName.get(draft.nameKey) ?? null;
    const key = reused?.key ?? uniqueTopicKey(slugifyTopic(draft.title.uz), takenKeys);
    takenKeys.add(key);
    return {
      subject,
      existingTopicId: reused?.id ?? null,
      key,
      title: draft.title,
      minGrade: draft.minGrade,
      maxGrade: Math.max(...draft.questions.map((q) => q.maxGrade)),
      position: reused ? reused.position : nextPosition++,
      questionIds: draft.questions.map((q) => q.id),
      activeQuestions:
        (reused?.activeQuestions ?? 0) + draft.questions.filter((q) => q.isActive).length,
    };
  });
}

/** Normallashtirilgan nom bo'yicha guruhlar, `(minGrade, title.uz)` tartibida. */
function draftsOf(questions: readonly BackfillQuestion[], skipped: BackfillPlan['skipped']): Draft[] {
  const drafts = new Map<string, Draft>();
  for (const q of questions) {
    const title = parseTopicText(q.topic, 'topic', TOPIC_TITLE_MAX);
    if (!title.ok) {
      skipped.push({ questionId: q.id, reason: title.error });
      continue;
    }
    const nameKey = normalizeTopicName(title.value.uz);
    const draft = drafts.get(nameKey);
    drafts.set(nameKey, {
      nameKey,
      title: draft?.title ?? title.value,
      minGrade: Math.min(draft?.minGrade ?? q.minGrade, q.minGrade),
      questions: [...(draft?.questions ?? []), q],
    });
  }
  return [...drafts.values()].sort(
    (a, b) =>
      a.minGrade - b.minGrade || compareText(a.title.uz, b.title.uz) || compareText(a.nameKey, b.nameKey),
  );
}

function sortQuestions(questions: readonly BackfillQuestion[]): BackfillQuestion[] {
  return [...questions].sort(
    (a, b) => compareText(a.externalId ?? '\uffff', b.externalId ?? '\uffff') || compareText(a.id, b.id),
  );
}
