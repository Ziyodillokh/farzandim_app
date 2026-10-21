// Kelajak progressi (docs/KELAJAK-REJA.md §4 `ProgressView`): yakunlangan
// sessiyalar natijalaridagi (`result.scores`) ballar Toshkent kuni bo'yicha
// yig'iladi (bir kunda bir nechta sessiya — javoblar soni bo'yicha o'rtacha).
// `latest` — oxirgi kun, `previous` — undan oldingi kun. wellbeing / safety
// bu yerga kirmaydi (`scores.categories`da ular yo'q).

import { DayKey } from '../../../common/time/tashkent';
import { RIASEC_CODES, RiasecCode, SCORED_CATEGORY_IDS, ScoredCategory } from './catalog';
import { CategoryScore, InterestDimension } from './scoring';

/** Grafikdagi nuqtalar soni (oxirgi kunlar). */
export const PROGRESS_MAX_POINTS = 12;
/** `improved` / `interestsRising` — shuncha yoki ko'proq o'sish. */
export const PROGRESS_RISE_MIN = 10;

export interface ProgressSession {
  day: DayKey;
  categories: readonly CategoryScore[];
  interests: readonly InterestDimension[];
}

export interface ProgressPoint {
  day: DayKey;
  score: number;
}

export interface ProgressTrend<K extends string> {
  key: K;
  latest: number;
  previous: number | null;
  delta: number | null;
  points: ProgressPoint[];
}

export interface KelajakProgress {
  categories: ProgressTrend<ScoredCategory>[];
  interests: ProgressTrend<RiasecCode>[];
  improved: ScoredCategory[];
  interestsRising: RiasecCode[];
}

interface Weighted {
  day: DayKey;
  score: number;
  answered: number;
}

/** Kun bo'yicha o'rtacha (javoblar soni og'irligi bilan), kunlar o'sish tartibida. */
function dailyPoints(entries: readonly Weighted[]): ProgressPoint[] {
  const days = [...new Set(entries.map((e) => e.day))].sort();
  return days.map((day) => {
    const sameDay = entries.filter((e) => e.day === day && e.answered > 0);
    const answered = sameDay.reduce((sum, e) => sum + e.answered, 0);
    const total = sameDay.reduce((sum, e) => sum + e.score * e.answered, 0);
    return { day, score: Math.round(total / answered) };
  });
}

function trend<K extends string>(key: K, entries: readonly Weighted[]): ProgressTrend<K> | null {
  const points = dailyPoints(entries.filter((e) => e.answered > 0));
  if (points.length === 0) return null;
  const latest = points[points.length - 1].score;
  const previous = points.length > 1 ? points[points.length - 2].score : null;
  return {
    key,
    latest,
    previous,
    delta: previous === null ? null : latest - previous,
    points: points.slice(-PROGRESS_MAX_POINTS),
  };
}

const rising = <K extends string>(trends: readonly ProgressTrend<K>[]) =>
  trends.filter((t) => t.delta !== null && t.delta >= PROGRESS_RISE_MIN).map((t) => t.key);

export function buildKelajakProgress(sessions: readonly ProgressSession[]): KelajakProgress {
  const categories = SCORED_CATEGORY_IDS.flatMap((category) => {
    const entries = sessions.flatMap((s) =>
      s.categories.filter((c) => c.category === category).map((c) => ({ day: s.day, ...c })),
    );
    const t = trend(category, entries);
    return t ? [t] : [];
  });
  const interests = RIASEC_CODES.flatMap((code) => {
    const entries = sessions.flatMap((s) =>
      s.interests.filter((d) => d.code === code).map((d) => ({ day: s.day, ...d })),
    );
    const t = trend(code, entries);
    return t ? [t] : [];
  });
  return { categories, interests, improved: rising(categories), interestsRising: rising(interests) };
}
