// ─────────────────────────────────────────────────────────────────────
// leaderboard-privacy — reytinglarda BOSHQA bolalarni identifikatsiyasiz
// ko'rsatish (App Store audit F16/F17)
// ─────────────────────────────────────────────────────────────────────
//
// Reyting barcha foydalanuvchilarga (begonalarga ham) ko'rinadi. Avval har
// qatorda bolaning `childId`si berilardi — klientlar undan
// `/children/:id/avatar/image` orqali bolaning RASMINI yuklardi, ya'ni
// istalgan foydalanuvchi barcha bolalarning rasmlarini yig'ib olishi mumkin
// edi. Endi `childId` faqat so'rovchining O'Z oilasidagi bola uchun
// qaytariladi; boshqalar uchun bo'sh satr (klientlar bo'sh id'da default
// avatar ko'rsatadi). Ism — faqat ism + familiya bosh harfi.

/** Ism ichida harf, belgi (diakritika) va o'zbekcha apostroflardan boshqasi. */
const NON_NAME_CHARS = /[^\p{L}\p{M}'’ʻʼ`-]/gu;
const HAS_LETTER = /\p{L}/u;
const MAX_FIRST_NAME_LENGTH = 20;
const HIDDEN_NAME = '—';

/**
 * Bola ismini reyting uchun NIQOBLAYDI: "Muhammad Abror Karimov" →
 * "Muhammad K." (ism + familiya bosh harfi).
 *
 * Ism bola/ota-ona tomonidan erkin kiritiladi — ichida telefon raqami yoki
 * @username bo'lishi mumkin. Shuning uchun raqam va maxsus belgilar olib
 * tashlanadi; harf qolmasa "—" qaytadi.
 */
export function maskChildName(full: string | null | undefined): string {
  const parts = (full ?? '')
    .trim()
    .split(/\s+/)
    .map((p) => p.replace(NON_NAME_CHARS, ''))
    .filter((p) => HAS_LETTER.test(p));
  if (parts.length === 0) return HIDDEN_NAME;

  const first = parts[0].slice(0, MAX_FIRST_NAME_LENGTH);
  if (parts.length === 1) return first;
  const lastInitial = (parts[parts.length - 1].match(HAS_LETTER)?.[0] ?? '').toUpperCase();
  return `${first} ${lastInitial}.`;
}

/**
 * Reyting qatoridagi `childId` — faqat so'rovchi oilasining bolasi uchun
 * haqiqiy id, boshqalar uchun bo'sh satr (rasm/profilga yo'l yo'q).
 */
export function visibleChildId(
  childId: string,
  ownChildIds: ReadonlySet<string>,
): string {
  return ownChildIds.has(childId) ? childId : '';
}
