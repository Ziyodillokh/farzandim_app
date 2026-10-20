// Prototip ifloslanishidan himoya: `__proto__`, `constructor`, `prototype` kalitlari
// har qanday chuqurlikda rad etiladi. `JSON.parse` ularni oddiy xossa sifatida
// yaratadi, zod v4 esa `__proto__`ni jimgina tashlab yuboradi — shuning uchun
// test ta'rifi (forma, JSON import, me'yorlar) saqlashdan OLDIN aniq tekshiriladi.
// Yurish iterativ (stek to'lmaydi), chuqurlik cheklangan.

const DANGEROUS_KEYS: ReadonlySet<string> = new Set(['__proto__', 'constructor', 'prototype']);
/** Haqiqiy test ta'rifi ~7 daraja; undan chuqur tuzilma — hujum yoki buzilgan fayl. */
export const MAX_JSON_DEPTH = 24;

export type UnsafeJson = { path: Array<string | number>; reason: 'key' | 'depth' };

type Frame = { value: unknown; path: Array<string | number> };

export function findUnsafeJson(root: unknown): UnsafeJson | null {
  const stack: Frame[] = [{ value: root, path: [] }];
  while (stack.length > 0) {
    const { value, path } = stack.pop() as Frame;
    if (value === null || typeof value !== 'object') continue;
    if (path.length > MAX_JSON_DEPTH) return { path, reason: 'depth' };
    if (Array.isArray(value)) {
      value.forEach((child, i) => stack.push({ value: child, path: [...path, i] }));
      continue;
    }
    for (const key of Object.keys(value)) {
      if (DANGEROUS_KEYS.has(key)) return { path: [...path, key], reason: 'key' };
      stack.push({ value: (value as Record<string, unknown>)[key], path: [...path, key] });
    }
  }
  return null;
}
