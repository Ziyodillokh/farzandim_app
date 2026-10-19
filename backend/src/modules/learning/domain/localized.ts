// Uch tilli matn (`{uz, ru, en}`) — savollar banki maydonlari.

export const LEARNING_LANGS = ['uz', 'ru', 'en'] as const;
export type LearningLang = (typeof LEARNING_LANGS)[number];
export type LocalizedText = Record<LearningLang, string>;

/**
 * Qiymatni uch tilli matnga aylantirish: oddiy satr — hamma tilda bir xil.
 * Xato bo'lsa xabar qaytaradi.
 */
export function parseLocalized(
  value: unknown,
  field: string,
  maxLength: number,
): { ok: true; value: LocalizedText } | { ok: false; error: string } {
  if (typeof value === 'string') {
    value = { uz: value, ru: value, en: value };
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { ok: false, error: `${field}: {uz, ru, en} obyekt kerak` };
  }
  const record = value as Record<string, unknown>;
  const result = {} as LocalizedText;
  for (const lang of LEARNING_LANGS) {
    const text = record[lang];
    if (typeof text !== 'string' || text.trim().length === 0) {
      return { ok: false, error: `${field}.${lang}: bo'sh` };
    }
    if (text.length > maxLength) {
      return { ok: false, error: `${field}.${lang}: ${maxLength} belgidan uzun` };
    }
    result[lang] = text.trim();
  }
  return { ok: true, value: result };
}
