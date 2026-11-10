/**
 * Taklif QR'i va havolasi. `farzandimedu.uz/link` — ochiq sahifa: telefon kamerasi bilan skanerlansa
 * kod va yo'riqnoma ko'rinadi, Parvoz Parents o'rnatilgan bo'lsa ilova o'zi ochiladi. Ilova ichidagi
 * skaner ham shu havoladan `code` ni oladi (xost ro'yxati — `Farzandim/lib/features/school/data/invite_code.dart`).
 */
export const INVITE_LINK_BASE = 'https://farzandimedu.uz/link?code=';

export function inviteLink(code: string): string {
  return `${INVITE_LINK_BASE}${encodeURIComponent(code)}`;
}

/** "ABCDEFGH" → "ABCD-EFGH"; 6 raqamli o'quvchi kodi → "048 213". */
export function formatInviteCode(code: string): string {
  if (/^\d{6}$/.test(code)) return `${code.slice(0, 3)} ${code.slice(3)}`;
  if (code.length === 8) return `${code.slice(0, 4)}-${code.slice(4)}`;
  return code;
}
