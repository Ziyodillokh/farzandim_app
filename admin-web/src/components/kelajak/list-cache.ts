import type { KelajakQuestion, Paginated } from '@/types/api.types';

/** Ro'yxat keshida bitta savolning faolligini almashtirish (boshqa qatorlarga tegmaydi). */
export function setActiveInList(
  old: Paginated<KelajakQuestion> | undefined,
  id: string,
  active: boolean,
): Paginated<KelajakQuestion> | undefined {
  return old ? { ...old, items: old.items.map((q) => (q.id === id ? { ...q, active } : q)) } : old;
}
