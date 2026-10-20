// Maktab xabarlari push matnlari — 3 tilda (uz / ru / en), qabul qiluvchi
// (ota-ona) tilida. Xodim yozgan sarlavha / matn TARJIMA QILINMAYDI — faqat
// qat'iy qism (maktab, xabar turi). To'lov matni hech qachon "qarz" demaydi:
// faqat maktab tasdiqlagan keyingi sana.

import type { PushPayload } from '../../common/fcm/fcm.service';
import type { NotifLang } from '../../common/i18n/notification-i18n';
import type { MessagePriority, ReminderKind } from './comms.schemas';

type Params = Record<string, string | number>;
type Texts = Record<NotifLang, string>;

/** Push matni chegarasi (bildirishnoma bannerida ko'rinadigan qism). */
const PUSH_BODY_MAX = 180;

const ANNOUNCEMENT_TITLE: Record<MessagePriority, Texts> = {
  NORMAL: {
    uz: "{school}: yangi e'lon",
    ru: '{school}: новое объявление',
    en: '{school}: new announcement',
  },
  IMPORTANT: {
    uz: "{school}: muhim e'lon",
    ru: '{school}: важное объявление',
    en: '{school}: important announcement',
  },
};

const REMINDER_KIND: Record<ReminderKind, Texts> = {
  MEETING: { uz: "Ota-onalar yig'ilishi", ru: 'Родительское собрание', en: 'Parent meeting' },
  EXAM: { uz: 'Nazorat ishi', ru: 'Контрольная работа', en: 'Exam' },
  EVENT: { uz: 'Maktab tadbiri', ru: 'Школьное мероприятие', en: 'School event' },
  HOLIDAY: { uz: "Ta'til", ru: 'Каникулы', en: 'Holiday' },
  ANNOUNCEMENT: { uz: "E'lon", ru: 'Объявление', en: 'Announcement' },
  SCHEDULE_CHANGE: { uz: "Jadval o'zgarishi", ru: 'Изменение расписания', en: 'Schedule change' },
};

const T = {
  'reminder.title': { uz: '{school}: {kind}', ru: '{school}: {kind}', en: '{school}: {kind}' },
  'payment.title': {
    uz: "{school}: to'lov eslatmasi",
    ru: '{school}: напоминание об оплате',
    en: '{school}: payment reminder',
  },
  'payment.body': {
    uz: "Maktab tasdiqlagan jadvalga ko'ra navbatdagi to'lov sanasi — {date}. To'lagan bo'lsangiz, ilovada \"Tekshirish\" tugmasini bosing.",
    ru: 'По графику школы следующая дата оплаты — {date}. Если вы уже оплатили, нажмите «Проверить» в приложении.',
    en: "Per the school's schedule, the next payment date is {date}. If you have already paid, tap “Check” in the app.",
  },
  'verification.title': {
    uz: "{school}: so'rovingizga javob berildi",
    ru: '{school}: ответ на ваш запрос',
    en: '{school}: your request was answered',
  },
} satisfies Record<string, Texts>;

function fill(template: string, params: Params): string {
  return template.replace(/\{(\w+)\}/g, (match, name: string) => (name in params ? String(params[name]) : match));
}

/** Banner uchun qisqartirish (so'z o'rtasida emas, "…" bilan). */
export function snippet(text: string, max = PUSH_BODY_MAX): string {
  const clean = text.replace(/\s+/g, ' ').trim();
  if (clean.length <= max) return clean;
  const cut = clean.slice(0, max - 1);
  const lastSpace = cut.lastIndexOf(' ');
  return `${(lastSpace > max / 2 ? cut.slice(0, lastSpace) : cut).trimEnd()}…`;
}

export function announcementPush(
  lang: NotifLang,
  a: { id: string; school: string; title: string; body: string; priority: MessagePriority },
): PushPayload {
  return {
    title: fill(ANNOUNCEMENT_TITLE[a.priority][lang], { school: a.school }),
    body: snippet(`${a.title} — ${a.body}`),
    data: { type: 'SCHOOL_ANNOUNCEMENT', announcementId: a.id },
  };
}

export function reminderPush(
  lang: NotifLang,
  r: { id: string; school: string; kind: ReminderKind; title: string; body: string },
): PushPayload {
  return {
    title: fill(T['reminder.title'][lang], { school: r.school, kind: REMINDER_KIND[r.kind][lang] }),
    body: snippet(`${r.title} — ${r.body}`),
    data: { type: 'SCHOOL_REMINDER', reminderId: r.id },
  };
}

export function paymentPush(
  lang: NotifLang,
  p: { id: string; school: string; nextDate: string },
): PushPayload {
  return {
    title: fill(T['payment.title'][lang], { school: p.school }),
    body: fill(T['payment.body'][lang], { date: p.nextDate }),
    data: { type: 'SCHOOL_PAYMENT_REMINDER', paymentReminderId: p.id },
  };
}

export function verificationAnsweredPush(
  lang: NotifLang,
  v: { id: string; school: string; answer: string; paymentReminderId: string },
): PushPayload {
  return {
    title: fill(T['verification.title'][lang], { school: v.school }),
    body: snippet(v.answer),
    data: { type: 'SCHOOL_VERIFICATION_ANSWERED', verificationId: v.id, paymentReminderId: v.paymentReminderId },
  };
}
