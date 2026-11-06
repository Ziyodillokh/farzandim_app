// Yutuqlar (badge) katalogi va sof funksiyalar (DB'siz).
//
// Katalog — koddagi konstanta: id'lar barqaror (ilova ham shularni biladi).
// Ochilgan id'lar `ChildProfile.achievements` (JSON ro'yxat) da, ochilgan vaqt
// `ChildProfile.achievementDates` da saqlanadi. Yutuq DON bermaydi.

export const BADGE_IDS = [
  'streak_7',
  'streak_30',
  'first_book',
  'olympian',
  'topic_master',
  'thinker',
] as const;

export type BadgeId = (typeof BADGE_IDS)[number];

/** Streak yutuqlari: ketma-ket faol kunlar chegarasi. */
const STREAK_BADGES: ReadonlyArray<{ id: BadgeId; days: number }> = [
  { id: 'streak_7', days: 7 },
  { id: 'streak_30', days: 30 },
];

export interface BadgeItem {
  id: BadgeId;
  earned: boolean;
  earnedAt: string | null;
}

export interface BadgeState {
  achievements: string[];
  dates: Record<string, string>;
}

/** Streak shu qiymatga yetganda ochiladigan yutuqlar. */
export function streakBadgesFor(streakDays: number): BadgeId[] {
  return STREAK_BADGES.filter((b) => streakDays >= b.days).map((b) => b.id);
}

export function readAchievements(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v): v is string => typeof v === 'string') : [];
}

export function readDates(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value).filter((e): e is [string, string] => typeof e[1] === 'string'),
  );
}

/**
 * Yangi ochilgan yutuqlar bilan YANGI holat (kiruvchi o'zgarmaydi); yangi hech
 * narsa bo'lmasa `null` (idempotent). `at` berilsa ochilish vaqti yoziladi,
 * `null` — keyinchalik to'ldirilgan (backfill): vaqt noma'lum.
 */
export function applyUnlocks(
  state: { achievements: unknown; achievementDates: unknown },
  ids: readonly string[],
  at: Date | null,
): BadgeState | null {
  const achievements = readAchievements(state.achievements);
  const fresh = [...new Set(ids)].filter((id) => !achievements.includes(id));
  if (fresh.length === 0) return null;
  const dates = readDates(state.achievementDates);
  return {
    achievements: [...achievements, ...fresh],
    dates: at ? { ...dates, ...Object.fromEntries(fresh.map((id) => [id, at.toISOString()])) } : dates,
  };
}

/** Katalog tartibida javob elementlari. */
export function toBadgeItems(achievements: unknown, achievementDates: unknown): BadgeItem[] {
  const earned = new Set(readAchievements(achievements));
  const dates = readDates(achievementDates);
  return BADGE_IDS.map((id) => ({
    id,
    earned: earned.has(id),
    earnedAt: earned.has(id) ? (dates[id] ?? null) : null,
  }));
}
