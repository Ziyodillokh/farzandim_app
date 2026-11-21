// To'lov muddati: navbatdagi sanaga necha kun qolgani (o'tib ketgan bo'lsa — manfiy) va ota-onaga ko'rsatiladigan
// qisqa qator. Eslatma sanadan `PAYMENT_NOTICE_DAYS` kun oldin boshlanadi va to'lov tasdiqlanmaguncha (maktab
// sanani keyingi davrga surmaguncha) har kuni davom etadi; shu oyna ichida «keldi» xabari ostida ham ko'rsatiladi.
// Matnda «qarz» so'zi ishlatilmaydi — platforma qarz hisoblamaydi, faqat maktab tasdiqlagan sanani eslatadi.

import { NotifLang } from '../../common/i18n/notification-i18n';
import { DayKey } from '../../common/time/tashkent';

/** Navbatdagi to'lov sanasidan shuncha kun oldin eslatish boshlanadi. */
export const PAYMENT_NOTICE_DAYS = 5;

const DAY_MS = 86_400_000;

/** `today` dan `nextDate` gacha kalendar kunlari (o'tib ketgan bo'lsa — manfiy). */
export function daysUntil(today: DayKey, nextDate: DayKey): number {
  return Math.round((Date.parse(`${nextDate}T00:00:00Z`) - Date.parse(`${today}T00:00:00Z`)) / DAY_MS);
}

/** Eslatma oynasidami: sanaga `PAYMENT_NOTICE_DAYS` yoki kamroq qolgan, yoki sana o'tib ketgan. */
export function isPaymentDue(today: DayKey, nextDate: DayKey): boolean {
  return daysUntil(today, nextDate) <= PAYMENT_NOTICE_DAYS;
}

/** "2026-11-25" → "25.11.2026". */
export function formatPaymentDate(day: DayKey): string {
  const [year, month, date] = day.split('-');
  return `${date}.${month}.${year}`;
}

const LINES: Record<'left' | 'today' | 'overdue', Record<NotifLang, string>> = {
  left: { uz: "To'lovga {days} kun qoldi ({date}).", ru: 'До оплаты осталось дней: {days} ({date}).', en: '{days} days left to pay ({date}).' },
  today: { uz: "Bugun to'lov kuni ({date}).", ru: 'Сегодня день оплаты ({date}).', en: 'Payment is due today ({date}).' },
  overdue: { uz: "To'lov sanasi {date} da o'tib ketgan.", ru: 'Срок оплаты прошёл {date}.', en: 'The payment date {date} has passed.' },
};

/** Ota-onaga qisqa qator: qancha kun qoldi, bugun, yoki qaysi sanada o'tib ketgan. */
export function paymentDueLine(lang: NotifLang, today: DayKey, nextDate: DayKey): string {
  const days = daysUntil(today, nextDate);
  const kind = days > 0 ? 'left' : days === 0 ? 'today' : 'overdue';
  return LINES[kind][lang].replace('{days}', String(days)).replace('{date}', formatPaymentDate(nextDate));
}
