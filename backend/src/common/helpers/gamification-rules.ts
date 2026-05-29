/**
 * Gamification: XP -> level/status, streak calculation. Pure functions (no DB).
 *
 * Status mapping (v2):
 *   < 300    -> "Boshlovchi"  (Lv 1-3)
 *   < 900    -> "Izlanuvchi"  (Lv 4-7)
 *   < 2000   -> "Bilimdon"    (Lv 8-12)
 *   < 5000   -> "Lider"       (Lv 13-20)
 *   >= 5000  -> "Mentor"      (Lv 20+)
 */

export function statusForXp(xp: number): string {
  if (xp < 300) return 'Boshlovchi';
  if (xp < 900) return 'Izlanuvchi';
  if (xp < 2000) return 'Bilimdon';
  if (xp < 5000) return 'Lider';
  return 'Mentor';
}

/**
 * Level: floor(sqrt(xp) / 5) + 1.
 * Negative XP returns level 1.
 */
export function levelForXp(xp: number): number {
  if (xp < 0) return 1;
  return Math.floor(Math.sqrt(xp) / 5) + 1;
}

/**
 * Streak: if active yesterday +1; if today - same; otherwise reset to 1.
 * `now` parameter can be injected for testing.
 */
export function calculateNewStreak(
  lastActivityDate: Date | null,
  currentStreak: number,
  now: Date = new Date(),
): { newStreak: number; isNewDay: boolean } {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  if (!lastActivityDate) {
    return { newStreak: 1, isNewDay: true };
  }

  const lastDay = new Date(
    lastActivityDate.getFullYear(),
    lastActivityDate.getMonth(),
    lastActivityDate.getDate(),
  );

  const diffDays = Math.round(
    (today.getTime() - lastDay.getTime()) / (1000 * 60 * 60 * 24),
  );

  if (diffDays === 0) {
    return { newStreak: currentStreak, isNewDay: false };
  }
  if (diffDays === 1) {
    return { newStreak: currentStreak + 1, isNewDay: true };
  }
  return { newStreak: 1, isNewDay: true };
}
