// Fastify @fastify/multipart field shape (bizning ko'p ishlatadigan tipimiz).
// `request.file()` qaytargan obyektning `fields` ichidagi tekst maydonlari shu
// shaklda keladi. Generic types ham bor, lekin biz string value ko'p ishlatamiz.

export interface MultipartField {
  value: string;
}

/**
 * Multipart fields'dan string qiymatni xavfsiz olish.
 * Yo'q bo'lsa undefined; bo'lsa trim qilingan string qaytaradi.
 */
export function getFieldString(
  fields: Record<string, unknown> | undefined,
  key: string,
): string | undefined {
  if (!fields) return undefined;
  const f = fields[key] as MultipartField | undefined;
  if (!f || typeof f.value !== 'string') return undefined;
  const trimmed = f.value.trim();
  return trimmed.length ? trimmed : undefined;
}

/**
 * Multipart fields'dan number olish. Yo'q yoki noto'g'ri bo'lsa undefined.
 */
export function getFieldNumber(
  fields: Record<string, unknown> | undefined,
  key: string,
): number | undefined {
  const s = getFieldString(fields, key);
  if (s === undefined) return undefined;
  const n = Number(s);
  return Number.isFinite(n) ? n : undefined;
}
