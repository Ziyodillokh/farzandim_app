/**
 * Kichik sozlamalar (til, mavzu, sessiya) — localStorage, `parvoz-school:` prefiksi.
 * Xususiy rejim yoki bloklangan xotirada xato bermaydi.
 */
const PREFIX = 'parvoz-school:';

export function readPref<T>(key: string): T | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = window.localStorage.getItem(PREFIX + key);
    return raw === null ? null : (JSON.parse(raw) as T);
  } catch {
    return null;
  }
}

export function writePref(key: string, value: unknown): void {
  if (typeof window === 'undefined') return;
  try {
    window.localStorage.setItem(PREFIX + key, JSON.stringify(value));
  } catch {
    // xotira to'la yoki bloklangan — sozlama shu sessiyada qoladi
  }
}

export function removePref(key: string): void {
  if (typeof window === 'undefined') return;
  try {
    window.localStorage.removeItem(PREFIX + key);
  } catch {
    // e'tiborsiz
  }
}

export const PREF_PREFIX = PREFIX;
