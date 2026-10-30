/**
 * Parvoz haqiqatda o'lchaydigan ko'rsatkichlar lug'ati (backend enumlari bilan
 * bir xil kalitlar). Nomlar i18n'da (`enums.*`). Manba: backend `LearningSubject`,
 * IQ bandlari (WISC-V), Kelajak RIASEC, "Bola ovozi" mavzulari, ilova toifalari.
 */

/** Daily Learning fanlari; `from` — o'qitiladigan birinchi sinf. */
export const SUBJECTS = [
  { key: 'MATH', from: 1 },
  { key: 'NATIVE', from: 1 },
  { key: 'ENGLISH', from: 1 },
  { key: 'RUSSIAN', from: 1 },
  { key: 'HISTORY', from: 5 },
  { key: 'BIOLOGY', from: 5 },
  { key: 'GEOGRAPHY', from: 5 },
  { key: 'INFORMATICS', from: 5 },
  { key: 'PHYSICS', from: 6 },
  { key: 'CHEMISTRY', from: 7 },
] as const;
export type Subject = (typeof SUBJECTS)[number]['key'];
export const SUBJECT_KEYS: readonly Subject[] = SUBJECTS.map((s) => s.key);

export function subjectFrom(subject: Subject): number {
  return SUBJECTS.find((s) => s.key === subject)?.from ?? 1;
}

/** IQ bandlari (WISC-V). LOW va VERY_LOW ko'rsatishda birga — "Rivojlanish zonasi". */
export const IQ_BANDS = ['VERY_HIGH', 'HIGH', 'ABOVE_AVERAGE', 'AVERAGE', 'BELOW_AVERAGE', 'LOW', 'VERY_LOW'] as const;
export type IqBand = (typeof IQ_BANDS)[number];
/** Ko'rsatish uchun: 6 qator (LOW + VERY_LOW = GROWTH_ZONE). */
export const IQ_DISPLAY_BANDS = ['VERY_HIGH', 'HIGH', 'ABOVE_AVERAGE', 'AVERAGE', 'BELOW_AVERAGE', 'GROWTH_ZONE'] as const;
export type IqDisplayBand = (typeof IQ_DISPLAY_BANDS)[number];
/** Standart ball chegaralari [min, max) — band. */
export const IQ_BAND_RANGES: Readonly<Record<IqBand, readonly [number, number]>> = {
  VERY_HIGH: [130, Infinity],
  HIGH: [120, 130],
  ABOVE_AVERAGE: [110, 120],
  AVERAGE: [90, 110],
  BELOW_AVERAGE: [80, 90],
  LOW: [70, 80],
  VERY_LOW: [-Infinity, 70],
};

/** Aralash IQ formasi yo'nalishlari. */
export const IQ_DOMAINS = ['FIGURAL', 'NUMERIC', 'VERBAL', 'LOGIC'] as const;
export type IqDomain = (typeof IQ_DOMAINS)[number];

/** Kelajak — RIASEC kasbiy qiziqishlar. */
export const RIASEC = ['R', 'I', 'A', 'S', 'E', 'C'] as const;
export type Riasec = (typeof RIASEC)[number];

/** Kasb sohalari (RIASEC'dan): bolalar qaysi sohalarga moyil. */
export const CAREER_FIELDS = ['IT', 'MEDICINE', 'ENGINEERING', 'EDUCATION', 'ARTS', 'BUSINESS', 'LAW', 'AGRO'] as const;
export type CareerField = (typeof CAREER_FIELDS)[number];
/** Har soha uchun RIASEC og'irliklari (top-kod → soha moyilligi). */
export const CAREER_FIELD_PROFILE: Readonly<Record<CareerField, Partial<Record<Riasec, number>>>> = {
  IT: { I: 0.55, R: 0.25, C: 0.2 },
  MEDICINE: { I: 0.5, S: 0.5 },
  ENGINEERING: { R: 0.6, I: 0.4 },
  EDUCATION: { S: 0.75, A: 0.25 },
  ARTS: { A: 0.85, E: 0.15 },
  BUSINESS: { E: 0.7, C: 0.3 },
  LAW: { E: 0.45, C: 0.35, S: 0.2 },
  AGRO: { R: 0.7, C: 0.3 },
};

/** Bola ilovasidagi umumiy qiziqishlar (`Child.interests`). */
export const INTERESTS = ['games', 'sport', 'tech', 'cartoon', 'music', 'animals', 'art', 'travel', 'science', 'book', 'space', 'food'] as const;
export type Interest = (typeof INTERESTS)[number];

/** "Bola ovozi" haftalik so'rovnoma mavzulari (0–100, yuqori — yaxshi). */
export const WELLBEING_TOPICS = ['WELLBEING', 'LEARNING', 'PEERS', 'SAFETY', 'SUPPORT'] as const;
export type WellbeingTopic = (typeof WELLBEING_TOPICS)[number];

/** Psixologga murojaat mavzulari. */
export const CARE_TOPICS = ['LEARNING', 'PEERS', 'EMOTIONS', 'FAMILY', 'BULLYING', 'SAFETY', 'OTHER'] as const;
export type CareTopic = (typeof CARE_TOPICS)[number];

/** Ilova toifalari (ekran vaqti). */
export const APP_CATEGORIES = ['VIDEO', 'GAME', 'SOCIAL', 'EDU', 'OTHER'] as const;
export type AppCategory = (typeof APP_CATEGORIES)[number];

/** Kayfiyat (Feedback.emoji). */
export const MOODS = ['HAPPY', 'EXCITED', 'LOVE', 'WINKING', 'THINKING', 'TIRED', 'SAD', 'ANGRY'] as const;
export type Mood = (typeof MOODS)[number];

/** Darajalar (farovonlik va signal ko'rsatkichlari uchun). */
export const LEVELS = ['GOOD', 'MIDDLE', 'LOW'] as const;
export type Level = (typeof LEVELS)[number];

/** Farovonlik mavzusi bali → daraja ("Bola ovozi": ≥72 barqaror, ≥60 kuzatib boring). */
export function topicLevel(score: number): Level {
  if (score >= 72) return 'GOOD';
  if (score >= 60) return 'MIDDLE';
  return 'LOW';
}

export const SCHOOL_TYPES = ['STATE', 'PRIVATE', 'SPECIAL'] as const;
export type SchoolType = (typeof SCHOOL_TYPES)[number];

export const GRADES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11] as const;
export type Grade = (typeof GRADES)[number];

export const GRADE_BANDS = ['ALL', 'G1_4', 'G5_9', 'G10_11'] as const;
export type GradeBand = (typeof GRADE_BANDS)[number];

export function gradesOf(band: GradeBand): readonly Grade[] {
  switch (band) {
    case 'G1_4':
      return [1, 2, 3, 4];
    case 'G5_9':
      return [5, 6, 7, 8, 9];
    case 'G10_11':
      return [10, 11];
    default:
      return GRADES;
  }
}

export const GENDERS = ['ALL', 'M', 'F'] as const;
export type GenderFilter = (typeof GENDERS)[number];
