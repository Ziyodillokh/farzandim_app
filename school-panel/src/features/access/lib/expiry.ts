/**
 * Bir martalik parol ko'rsatilgan oynaning yopilish muddati (sof hisob; oyna `components/credentials-dialog.tsx`).
 * Muddat `Date.now()` bo'yicha — brauzer yopiq tabdagi taymerlarni sekinlatsa ham to'g'ri hisoblanadi.
 */

/** Parol ochiq turishi mumkin bo'lgan eng uzun harakatsiz vaqt. */
export const REVEAL_TTL_MS = 5 * 60_000;
/** Yopilishdan shuncha oldin ogohlantiriladi (WCAG 2.2.1: kamida 20 soniya, oddiy harakat bilan uzaytirish). */
export const REVEAL_WARN_MS = 20_000;
export const REVEAL_MINUTES = REVEAL_TTL_MS / 60_000;

export type RevealExpiry = { expired: true } | { expired: false; secondsLeft: number | null };

/** `secondsLeft` — faqat oxirgi `warnMs` ichida (ogohlantirish), aks holda `null`. */
export function revealExpiry(deadlineMs: number, nowMs: number, warnMs: number = REVEAL_WARN_MS): RevealExpiry {
  const left = deadlineMs - nowMs;
  if (left <= 0) return { expired: true };
  return { expired: false, secondsLeft: left <= warnMs ? Math.ceil(left / 1000) : null };
}
