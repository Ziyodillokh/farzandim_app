// Ota-ona telefoni bilan ishlash: haqiqiy telefonni ajratish, moslash uchun oxirgi raqamlar va xodimga ko'rsatish
// uchun niqob. Telegram orqali kirgan foydalanuvchida `User.phone` o'rnida vaqtinchalik `tg:<id>` turadi — u
// haqiqiy telefon EMAS: hech qachon moslashda, saqlashda yoki ko'rsatishda ishlatilmaydi.

const TELEGRAM_PLACEHOLDER = 'tg:';
const PHONE_TAIL = 9;
const VISIBLE_DIGITS = 4;
const UZ_NUMBER = /^998\d{9}$/;

/** Haqiqiy telefon yoki bo'sh qator (`tg:…` va bo'sh qiymat — bo'sh). */
export const realPhone = (phone: string | null | undefined): string =>
  phone && !phone.startsWith(TELEGRAM_PLACEHOLDER) ? phone : '';

/** Moslash kaliti: telefonning oxirgi 9 raqami (formatlash va davlat kodidan qat'i nazar); yo'q bo'lsa `null`. */
export function phoneTail(phone: string | null | undefined): string | null {
  const digits = realPhone(phone).replace(/\D/g, '');
  return digits.length >= PHONE_TAIL ? digits.slice(-PHONE_TAIL) : null;
}

/**
 * Xodim ro'yxati uchun niqoblangan telefon: faqat oxirgi 4 raqam ko'rinadi. O'zbekiston raqami — `+998 ** *** 12 34`.
 * Haqiqiy telefon yo'q (yoki 4 raqamdan kam) bo'lsa — `null`.
 */
export function maskPhone(phone: string | null | undefined): string | null {
  const real = realPhone(phone).trim();
  const digits = real.replace(/\D/g, '');
  if (digits.length < VISIBLE_DIGITS) return null;
  const tail = digits.slice(-VISIBLE_DIGITS);
  const visible = `${tail.slice(0, 2)} ${tail.slice(2)}`;
  if (UZ_NUMBER.test(digits)) return `+998 ** *** ${visible}`;
  return `${real.startsWith('+') ? '+' : ''}${'*'.repeat(digits.length - VISIBLE_DIGITS)} ${visible}`;
}
