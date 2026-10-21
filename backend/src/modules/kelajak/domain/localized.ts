// Kelajak matni — `{uz, ru?, en?}`. Bank savollari faqat o'zbekcha; ilovalar
// `ru`/`en` bo'lmasa `uz`ni ko'rsatadi (docs/KELAJAK-REJA.md §1).

export const KELAJAK_LANGS = ['uz', 'ru', 'en'] as const;
export type KelajakLang = (typeof KELAJAK_LANGS)[number];

/** Mahalliylashtirilgan matn (`uz` majburiy). */
export type L = Readonly<{ uz: string; ru?: string; en?: string }>;

export type LocalizedResult =
  | { ok: true; value: L }
  | { ok: false; error: string };

/**
 * Qiymatni `L`ga aylantirish: oddiy satr — `{uz}`. `uz` 1..max belgi,
 * `ru`/`en` ixtiyoriy (bo'sh satr — yo'q deb olinadi).
 */
export function parseL(value: unknown, field: string, maxLength: number): LocalizedResult {
  const record =
    typeof value === 'string'
      ? { uz: value }
      : value && typeof value === 'object' && !Array.isArray(value)
        ? (value as Record<string, unknown>)
        : null;
  if (!record) return { ok: false, error: `${field}: matn yoki {uz, ru?, en?} kerak` };

  const result: Partial<Record<KelajakLang, string>> = {};
  for (const lang of KELAJAK_LANGS) {
    const raw = record[lang];
    if (raw === undefined || raw === null) continue;
    if (typeof raw !== 'string') return { ok: false, error: `${field}.${lang}: satr bo'lishi kerak` };
    const text = raw.trim();
    if (text.length > maxLength) {
      return { ok: false, error: `${field}.${lang}: ${maxLength} belgidan uzun` };
    }
    if (text.length > 0) result[lang] = text;
  }
  if (!result.uz) return { ok: false, error: `${field}.uz: bo'sh` };
  return { ok: true, value: result as L };
}
