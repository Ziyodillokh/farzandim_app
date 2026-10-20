// Kunlik test mukofoti (ilovadagi `donFor` bilan bir xil).

/** Muvaffaqiyatli natija chegarasi (foiz). */
export const SUCCESS_PERCENT = 80;

export const DON_PER_CORRECT = 2;
export const PERFECT_BONUS_DON = 10;
export const XP_PER_CORRECT = 5;

export function donFor(correct: number, total: number): number {
  if (total <= 0 || correct <= 0) return 0;
  return correct * DON_PER_CORRECT + (correct === total ? PERFECT_BONUS_DON : 0);
}

export function xpFor(correct: number, total: number): number {
  if (total <= 0 || correct <= 0) return 0;
  return correct * XP_PER_CORRECT;
}

export function percentOf(correct: number, total: number): number {
  return total <= 0 ? 0 : Math.round((correct * 100) / total);
}
