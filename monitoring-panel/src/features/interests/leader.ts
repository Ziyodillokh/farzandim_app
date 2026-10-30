/** Ulushli element (fan, qiziqish, kasbiy tip, soha). `null` — ulush yashirilgan yoki yo'q. */
type Shared = { share: number | null };

/** Hech bo'lmasa bitta musbat ulush bormi (aks holda — "ma'lumot yo'q", "0,0%" ustunlar emas). */
export function hasShares(items: readonly Shared[]): boolean {
  return items.some((i) => i.share !== null && i.share > 0);
}

/**
 * Yetakchi: eng katta musbat ulushli element (tenglikda — ro'yxatdagi birinchisi).
 * Hamma ulush 0 yoki yo'q bo'lsa — yetakchi yo'q: birinchi kalit "yetakchi" deb
 * ko'rsatilmaydi. Ro'yxat tartibiga tayanmaydi.
 */
export function leader<T extends Shared>(items: readonly T[]): T | undefined {
  return items.reduce<T | undefined>((best, item) => (item.share !== null && item.share > 0 && item.share > (best?.share ?? 0) ? item : best), undefined);
}
