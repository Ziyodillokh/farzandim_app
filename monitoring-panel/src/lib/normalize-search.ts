/**
 * Qidiruv uchun normallashtirish: kichik harf, o'zbek apostroflarining barcha
 * shakllari (ʻ ' ` ’ ‘) bitta belgiga, ortiqcha bo'shliqlar — bitta.
 * "Gʻulomov", "G'ulomov", "G`ulomov" — bir xil topiladi.
 */
const APOSTROPHES = /[ʻʼ’‘`´']/g;

export function normalizeSearch(value: string): string {
  return value.toLowerCase().replace(APOSTROPHES, "'").replace(/\s+/g, ' ').trim();
}

export function matchesSearch(haystack: string, query: string): boolean {
  const q = normalizeSearch(query);
  if (!q) return true;
  return normalizeSearch(haystack).includes(q);
}
