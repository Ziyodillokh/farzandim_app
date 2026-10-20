/**
 * Audit yozuvining "oldin/keyin" holatini o'qiladigan maydon farqiga aylantirish.
 * Ichma-ich obyektlar `a.b` ko'rinishida (2 darajagacha) yoyiladi.
 */
export type DiffKind = 'added' | 'removed' | 'changed' | 'same';
export type DiffRow = { field: string; before: unknown; after: unknown; kind: DiffKind };

const MAX_DEPTH = 2;
const SCALAR_KEY = 'value';

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function flatten(value: Record<string, unknown>, prefix: string, depth: number): Array<[string, unknown]> {
  return Object.entries(value).flatMap(([key, v]): Array<[string, unknown]> => {
    const path = prefix ? `${prefix}.${key}` : key;
    return isPlainObject(v) && depth + 1 < MAX_DEPTH ? flatten(v, path, depth + 1) : [[path, v]];
  });
}

function toFlat(value: unknown): Map<string, unknown> {
  if (value === null || value === undefined) return new Map();
  if (!isPlainObject(value)) return new Map([[SCALAR_KEY, value]]);
  return new Map(flatten(value, '', 0));
}

function same(a: unknown, b: unknown): boolean {
  return JSON.stringify(a) === JSON.stringify(b);
}

export function diffValues(before: unknown, after: unknown): DiffRow[] {
  const a = toFlat(before);
  const b = toFlat(after);
  const fields = [...new Set([...a.keys(), ...b.keys()])];
  return fields.map((field) => {
    const inBefore = a.has(field);
    const inAfter = b.has(field);
    const kind: DiffKind = !inBefore ? 'added' : !inAfter ? 'removed' : same(a.get(field), b.get(field)) ? 'same' : 'changed';
    return { field, before: a.get(field), after: b.get(field), kind };
  });
}

/** Yozuv turi: yaratish (oldin yo'q), o'chirish (keyin yo'q), o'zgartirish yoki tafsilotsiz. */
export function auditShape(before: unknown, after: unknown): 'create' | 'delete' | 'update' | 'none' {
  const hasBefore = before !== null && before !== undefined;
  const hasAfter = after !== null && after !== undefined;
  if (hasBefore && hasAfter) return 'update';
  if (hasAfter) return 'create';
  if (hasBefore) return 'delete';
  return 'none';
}
