// Mavzu va rol yorliqlari: panel bildirishnomasi (uz / ru) va ota-onaga push (uz / ru / en).

import type { PushPayload } from '../../common/fcm/fcm.service';
import type { NotifLang } from '../../common/i18n/notification-i18n';
import { snippet } from './parent-contacts';
import type { ParentTopic } from './parent-connect.schemas';

type Texts = Record<NotifLang, string>;

export const TOPIC_LABELS: Record<ParentTopic, Texts> = {
  ABSENCE: { uz: 'Darsga kelmaydi', ru: 'Пропуск занятий', en: 'Absence' },
  EARLY_PICKUP: { uz: 'Erta olib ketish', ru: 'Ранний уход', en: 'Early pickup' },
  HOMEWORK: { uz: 'Uy vazifasi', ru: 'Домашнее задание', en: 'Homework' },
  PROGRESS: { uz: "O'zlashtirish", ru: 'Успеваемость', en: 'Progress' },
  MEETING: { uz: 'Uchrashuv', ru: 'Встреча', en: 'Meeting' },
  BEHAVIOR: { uz: 'Xulq-atvor', ru: 'Поведение', en: 'Behaviour' },
  WELLBEING: { uz: 'Kayfiyat va holat', ru: 'Самочувствие', en: 'Wellbeing' },
  BULLYING: { uz: 'Bulling xavotiri', ru: 'Травля', en: 'Bullying concern' },
  ADVICE: { uz: 'Maslahat', ru: 'Консультация', en: 'Advice' },
  PAYMENT: { uz: "To'lov", ru: 'Оплата', en: 'Payment' },
  DOCUMENT: { uz: 'Hujjat / maʼlumotnoma', ru: 'Документ / справка', en: 'Document' },
  SUGGESTION: { uz: 'Taklif', ru: 'Предложение', en: 'Suggestion' },
  PROBLEM: { uz: 'Muammo', ru: 'Проблема', en: 'Problem' },
  THANKS: { uz: 'Minnatdorchilik', ru: 'Благодарность', en: 'Thanks' },
  EXTRA_LESSON: { uz: "Qo'shimcha dars", ru: 'Дополнительное занятие', en: 'Extra lesson' },
  OTHER: { uz: 'Boshqa', ru: 'Другое', en: 'Other' },
};

const ROLE_LABELS: Record<string, Texts> = {
  DIRECTOR: { uz: 'Direktor', ru: 'Директор', en: 'Principal' },
  ADMIN: { uz: "Ma'muriyat", ru: 'Администрация', en: 'Administration' },
  HOMEROOM: { uz: 'Sinf rahbari', ru: 'Классный руководитель', en: 'Class teacher' },
  PSYCHOLOGIST: { uz: 'Psixolog', ru: 'Психолог', en: 'Psychologist' },
  TEACHER: { uz: "O'qituvchi", ru: 'Учитель', en: 'Teacher' },
};

const REPLY_TITLE: Texts = { uz: '{school}: {role} javob berdi', ru: '{school}: ответ — {role}', en: '{school}: {role} replied' };
const PRIVATE_BODY: Texts = {
  uz: "Yangi javob — Parvoz ilovasida o'qing",
  ru: 'Новый ответ — прочитайте в приложении Parvoz',
  en: 'New reply — read it in the Parvoz app',
};

/** Push `data.type` — ilova yozishmani ochadi. */
export const PARENT_MESSAGE_PUSH_TYPE = 'SCHOOL_PARENT_MESSAGE';

export function topicLabel(topic: string | null | undefined): { uz: string; ru: string } {
  const t = TOPIC_LABELS[(topic ?? 'OTHER') as ParentTopic] ?? TOPIC_LABELS.OTHER;
  return { uz: t.uz, ru: t.ru };
}

/**
 * Xodim javobi haqida ota-onaga push. Psixolog javobining matni bildirishnoma
 * bannerida ko'rsatilmaydi (telefon ekrani boshqalarga ko'rinishi mumkin).
 */
export function replyPush(
  lang: NotifLang,
  v: { threadId: string; school: string; role: string; body: string },
): PushPayload {
  const role = (ROLE_LABELS[v.role] ?? ROLE_LABELS.TEACHER!)[lang];
  return {
    title: REPLY_TITLE[lang].replace('{school}', v.school).replace('{role}', role).replace(/^: /, ''),
    body: v.role === 'PSYCHOLOGIST' ? PRIVATE_BODY[lang] : snippet(v.body, 180),
    data: { type: PARENT_MESSAGE_PUSH_TYPE, threadId: v.threadId },
  };
}
