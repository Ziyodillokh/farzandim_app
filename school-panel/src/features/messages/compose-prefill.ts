'use client';

import { useQuery } from '@tanstack/react-query';

import { api } from '@/data/api';

/** Chuqur havola: `/messages/new?classId=cls-7a` yoki `?guardianId=g1,g2` — auditoriya oldindan tanlanadi. */
export type ComposePrefill = { classIds: string[]; guardianIds: string[] };

export const EMPTY_PREFILL: ComposePrefill = { classIds: [], guardianIds: [] };

const MAX_IDS = 50;
const ID_PATTERN = /^[\w-]{1,64}$/;
/** `paginate` bir sahifada ko'pi bilan 500 ta qaytaradi. */
const PAGE_LIMIT = 500;

function parseIds(raw: string | null): string[] {
  if (!raw) return [];
  const ids = raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => ID_PATTERN.test(s));
  return [...new Set(ids)].slice(0, MAX_IDS);
}

/** URL parametrlarini tekshirib o'qish (noto'g'ri qiymatlar tashlab yuboriladi). */
export function parseComposePrefill(params: Pick<URLSearchParams, 'get'>): ComposePrefill {
  return { classIds: parseIds(params.get('classId')), guardianIds: parseIds(params.get('guardianId')) };
}

/**
 * Oldindan tanlangan ota-onalar nomi — `api.guardians.list` dan (doira servisda:
 * sinf rahbari faqat o'z sinfi ota-onalarini oladi; topilmaganlar ro'yxatda bo'lmaydi).
 */
async function guardianNames(ids: readonly string[]): Promise<Record<string, string>> {
  const wanted = new Set(ids);
  const found: Record<string, string> = {};
  for (let page = 1; ; page += 1) {
    const result = await api.guardians.list({ page, limit: PAGE_LIMIT });
    for (const g of result.items) if (wanted.has(g.id)) found[g.id] = g.fullName;
    if (Object.keys(found).length === wanted.size || page >= result.pagination.totalPages) return found;
  }
}

export function usePrefillGuardianNames(ids: readonly string[]) {
  return useQuery({
    queryKey: ['guardians', 'prefill-names', ids] as const,
    queryFn: () => guardianNames(ids),
    enabled: ids.length > 0,
    staleTime: 60_000,
  });
}
