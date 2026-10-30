/**
 * Bola ovozi — k-anonimlik. Direktor/administrator faqat umumlashgan natija
 * ko'radi: respondentlar soni K dan kam guruh yashiriladi. Agar aynan bitta
 * guruh yashirilsa, uni "jami − qolganlar" orqali hisoblab bo'lmasligi uchun
 * keyingi eng kichik guruh ham yashiriladi (ikkilamchi yashirish).
 */
export const CARE_MIN_GROUP = 5;

export type GroupStat<T> = { key: string; label: string; respondents: number; value: T };
export type MaskedGroup<T> = GroupStat<T> & { hidden: boolean };

export function applyKAnonymity<T>(groups: readonly GroupStat<T>[], k = CARE_MIN_GROUP): MaskedGroup<T>[] {
  const masked = groups.map((g) => ({ ...g, hidden: g.respondents < k }));
  const hiddenCount = masked.filter((g) => g.hidden).length;
  if (hiddenCount === 1) {
    const candidates = masked
      .map((g, index) => ({ g, index }))
      .filter(({ g }) => !g.hidden)
      .sort((a, b) => a.g.respondents - b.g.respondents);
    const next = candidates[0];
    if (next) masked[next.index] = { ...next.g, hidden: true };
  }
  return masked;
}

/** Kichik sonlarni "<5" ko'rinishida (murojaatlar soni direktor uchun). */
export function maskSmallCount(count: number, k = CARE_MIN_GROUP): string {
  return count > 0 && count < k ? `<${k}` : String(count);
}
