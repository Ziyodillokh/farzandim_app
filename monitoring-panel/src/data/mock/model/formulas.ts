/**
 * Qatlam (hudud/tuman × sinf × jins × maktab turi × oy) darajasidagi demo
 * formulalar. Har formula Parvoz haqiqatda o'lchaydigan ko'rsatkichning
 * ma'nosiga mos: o'zlashtirish — to'g'ri javoblar %, IQ — standart ball
 * taqsimoti, farovonlik — "Bola ovozi" mavzu bali (0–100) va h.k.
 * Natijalar deterministik (xesh shovqin), chegaralar real oraliqda.
 */
import {
  APP_CATEGORIES,
  type AppCategory,
  CARE_TOPICS,
  type CareTopic,
  type Grade,
  INTERESTS,
  type Interest,
  IQ_BAND_RANGES,
  IQ_BANDS,
  type IqBand,
  type IqDomain,
  MOODS,
  type Mood,
  RIASEC,
  type Riasec,
  type SchoolType,
  type Subject,
  subjectFrom,
  SUBJECT_KEYS,
  type WellbeingTopic,
} from '@/data/reference/domains';
import type { Latent } from './latent';
import { signedNoise } from './latent';
import type { Gender } from './population';

export type Ctx = {
  /** Shovqin kaliti: hudud yoki tuman id. */
  key: string;
  L: Latent;
  grade: Grade;
  gender: Gender;
  type: SchoolType;
  /** O'quv oyi indeksi (2024-09 → 0). */
  t: number;
  /** Kalendar oyi (1..12). */
  month: number;
};

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
const isF = (c: Ctx) => c.gender === 'F';
const inRange = (g: number, lo: number, hi: number) => g >= lo && g <= hi;

// ───────────────────────────── Qamrov va faollik ─────────────────────────────

/** 30 kunda faol o'quvchilar ulushi (0..1). */
export function activeRate(c: Ctx): number {
  const season: Record<number, number> = { 9: -0.04, 10: 0, 11: 0.01, 12: -0.02, 1: -0.06, 2: 0, 3: 0.01, 4: 0.02, 5: -0.03 };
  const gradeFx = c.grade <= 2 ? -0.08 : inRange(c.grade, 5, 9) ? 0.03 : 0;
  return clamp(0.66 + 0.28 * (c.L.digital - 0.6) + gradeFx + (season[c.month] ?? 0) + 0.003 * c.t + signedNoise('act', c.key) * 0.03, 0.3, 0.95);
}

/** Kamida bitta ota-ona ilovaga ulangan o'quvchilar ulushi (0..1). */
export function parentsLinked(c: Ctx): number {
  return clamp(0.5 + 0.3 * (c.L.digital - 0.6) + 0.12 * (c.L.urban - 0.5) + 0.008 * c.t + signedNoise('par', c.key) * 0.04, 0.25, 0.9);
}

/** Ota-ona telefoni bilan bog'langan qurilmalar ulushi (raqamli odatlar bazasi). */
export function deviceShare(c: Ctx): number {
  const gradeFx = c.grade <= 2 ? -0.12 : c.grade >= 8 ? 0.06 : 0;
  return clamp(0.3 + 0.22 * (c.L.digital - 0.6) + gradeFx + 0.004 * c.t, 0.1, 0.7);
}

/** Haftalik "Bola ovozi" so'rovnomasida qatnashish (0..1). */
export function surveyParticipation(c: Ctx): number {
  return clamp(0.72 + 0.12 * (c.L.climate - 0.65) + signedNoise('srv', c.key) * 0.04 - (c.grade <= 2 ? 0.2 : 0), 0.35, 0.92);
}

// ───────────────────────────── O'zlashtirish ─────────────────────────────

const SUBJECT_OFFSET: Record<Subject, (c: Ctx) => number> = {
  MATH: () => -2,
  NATIVE: (c) => 6 + (isF(c) ? 1.2 : -0.6),
  ENGLISH: (c) => -5 + 11 * (c.L.digital - 0.6) + (isF(c) ? 1.4 : -0.4),
  RUSSIAN: (c) => -2 + 9 * (c.L.urban - 0.5),
  HISTORY: () => 3,
  BIOLOGY: () => 2,
  GEOGRAPHY: () => 1,
  INFORMATICS: (c) => -2 + 9 * (c.L.digital - 0.6) + (isF(c) ? -0.4 : 0.8),
  PHYSICS: () => -7.5,
  CHEMISTRY: () => -9.5,
};

const MASTERY_SEASON: Record<number, number> = { 9: -1.6, 10: -0.7, 11: 0, 12: 0.3, 1: -0.5, 2: 0.4, 3: 0.6, 4: 0.9, 5: 0.6 };

/** Fanlar bo'yicha o'sish sur'ati (Parvoz mashqlari ko'proq bo'lgan fanlarda tezroq). */
const SUBJECT_TREND: Record<Subject, number> = {
  ENGLISH: 1.7, INFORMATICS: 1.5, MATH: 1.25, BIOLOGY: 1, NATIVE: 0.85, RUSSIAN: 0.9,
  HISTORY: 0.9, GEOGRAPHY: 0.8, PHYSICS: 0.7, CHEMISTRY: 0.5,
};

/** Fan bo'yicha o'rtacha to'g'ri javoblar % (fan shu sinfda o'qitilmasa — null). */
export function mastery(c: Ctx, subject: Subject): number | null {
  if (c.grade < subjectFrom(subject)) return null;
  const base = 63 + 15 * (c.L.resource - 0.55) + 4 * (c.L.urban - 0.5);
  const gradeFx = 5.5 - 0.75 * (c.grade - 1);
  const genderFx = isF(c) ? 1.2 : 0;
  const typeFx = c.type === 'PRIVATE' ? 6 : c.type === 'SPECIAL' ? 9 : 0;
  // Parvoz ta'siri: oyiga ~0,11 p.p. o'sish, hududlarda biroz farqli.
  const trend = (0.11 + signedNoise('tr', c.key) * 0.04) * SUBJECT_TREND[subject] * c.t;
  const noise = signedNoise('m', c.key, subject) * 2.6 + signedNoise('mg', c.key, subject, c.grade) * 1.4;
  return clamp(base + SUBJECT_OFFSET[subject](c) + gradeFx + genderFx + typeFx + (MASTERY_SEASON[c.month] ?? 0) + trend + noise, 22, 97);
}

/** 80% va undan yuqori natijali testlar ulushi (%), o'zlashtirishdan logistik bog'liq. */
export function successRate(m: number): number {
  return 100 / (1 + Math.exp(-(m - 77) / 6.5));
}

/** Faol o'quvchiga haftasiga testlar. */
export function testsPerWeek(c: Ctx): number {
  return clamp(3.1 + 2.2 * (c.L.digital - 0.6) + (inRange(c.grade, 5, 9) ? 0.4 : 0) + signedNoise('tpw', c.key) * 0.3, 1.2, 6);
}

// ───────────────────────────── Qiziqishlar ─────────────────────────────

const SUBJECT_INTEREST_BASE: Record<Subject, number> = {
  MATH: 0.56, ENGLISH: 0.6, NATIVE: 0.4, RUSSIAN: 0.27, HISTORY: 0.25, BIOLOGY: 0.23,
  GEOGRAPHY: 0.15, INFORMATICS: 0.45, PHYSICS: 0.19, CHEMISTRY: 0.15,
};

/** Bola profilida fanni tanlash ehtimoli (0..1). */
export function subjectInterest(c: Ctx, subject: Subject): number | null {
  if (c.grade < subjectFrom(subject)) return null;
  const f = isF(c);
  let v = SUBJECT_INTEREST_BASE[subject];
  switch (subject) {
    case 'ENGLISH':
      v += 0.12 * (c.L.urban - 0.5) + 0.08 * (c.L.digital - 0.6) + (f ? 0.04 : 0);
      break;
    case 'INFORMATICS':
      v += 0.16 * (c.L.digital - 0.6) + (f ? -0.05 : 0.06);
      break;
    case 'RUSSIAN':
      v += 0.2 * (c.L.urban - 0.5);
      break;
    case 'BIOLOGY':
      v += 0.08 * (c.L.agro - 0.5) + (f ? 0.06 : -0.02);
      break;
    case 'NATIVE':
      v += -0.06 * (c.L.urban - 0.5) + (f ? 0.05 : -0.02);
      break;
    case 'MATH':
      v += f ? -0.01 : 0.03;
      break;
    case 'PHYSICS':
      v += f ? -0.04 : 0.05;
      break;
    case 'CHEMISTRY':
      v += f ? 0.04 : -0.01;
      break;
    default:
      break;
  }
  if (c.grade >= 10 && (subject === 'MATH' || subject === 'ENGLISH' || subject === 'BIOLOGY' || subject === 'CHEMISTRY')) v += 0.06;
  return clamp(v + signedNoise('si', c.key, subject) * 0.03, 0.03, 0.92);
}

const INTEREST_BASE: Record<Interest, number> = {
  games: 0.5, sport: 0.44, tech: 0.38, cartoon: 0.34, music: 0.32, animals: 0.31,
  art: 0.28, travel: 0.27, science: 0.26, book: 0.22, space: 0.21, food: 0.18,
};

export function generalInterest(c: Ctx, interest: Interest): number {
  const f = isF(c);
  const g = c.grade;
  let v = INTEREST_BASE[interest];
  if (interest === 'cartoon') v += g <= 4 ? 0.25 : g >= 8 ? -0.2 : 0;
  if (interest === 'games') v += f ? -0.08 : 0.12;
  if (interest === 'sport') v += f ? -0.06 : 0.08;
  if (interest === 'art') v += f ? 0.09 : -0.04;
  if (interest === 'music') v += (f ? 0.05 : 0) + (g >= 8 ? 0.05 : 0);
  if (interest === 'tech') v += (f ? -0.05 : 0.08) + 0.1 * (c.L.digital - 0.6);
  if (interest === 'science') v += inRange(g, 5, 9) ? 0.04 : 0;
  if (interest === 'book') v += (f ? 0.05 : 0) + (g <= 6 ? 0.03 : 0);
  if (interest === 'animals') v += g <= 5 ? 0.08 : -0.03;
  if (interest === 'travel') v += (g >= 8 ? 0.05 : 0) + 0.05 * (c.L.urban - 0.5);
  if (interest === 'space') v += inRange(g, 4, 8) ? 0.05 : 0;
  return clamp(v + signedNoise('gi', c.key, interest) * 0.03, 0.03, 0.9);
}

/** RIASEC o'lchov bali (0..100); Kelajak 7–18 yosh (1-sinfdan) — 3-sinfdan ishonchli. */
export function riasecScore(c: Ctx, code: Riasec): number | null {
  if (c.grade < 3) return null;
  const f = isF(c);
  let v: number;
  switch (code) {
    case 'R':
      v = 50 + 10 * (c.L.agro - 0.5) + (f ? -4 : 6);
      break;
    case 'I':
      v = 57 + 8 * (c.L.resource - 0.55) + 6 * (c.L.urban - 0.5) + (f ? 0 : 2);
      break;
    case 'A':
      v = 52 + (f ? 6 : -2) + (c.grade <= 6 ? 5 : 0);
      break;
    case 'S':
      v = 55 + (f ? 6 : -3) + 4 * (c.L.climate - 0.65);
      break;
    case 'E':
      v = 51 + 9 * (c.L.urban - 0.5) + (f ? 0 : 3) + (c.grade >= 9 ? 3 : 0);
      break;
    default:
      v = 48 + 3 * (c.L.resource - 0.55) + (f ? 2 : 0);
  }
  return clamp(v + signedNoise('ri', c.key, code) * 2, 20, 90);
}

/** Yetakchi RIASEC kodi ulushlari (softmax, harorat 8). */
export function riasecTopShares(scores: Readonly<Record<Riasec, number>>): Record<Riasec, number> {
  const exps = RIASEC.map((code) => Math.exp(scores[code] / 8));
  const total = exps.reduce((a, b) => a + b, 0);
  return Object.fromEntries(RIASEC.map((code, i) => [code, (exps[i] as number) / total])) as Record<Riasec, number>;
}

/** Kasbga tayyorgarlik (Kelajak `career_planning`), 7-sinfdan. */
export function careerReadiness(c: Ctx): number | null {
  if (c.grade < 7) return null;
  return clamp(50 + 1.7 * (c.grade - 7) + 7 * (c.L.resource - 0.55) + signedNoise('cr', c.key) * 2.5 + 0.06 * c.t, 30, 85);
}

// ───────────────────────────── IQ ─────────────────────────────

/** IQ testida qatnashish (9–20 yosh ≈ 3-sinfdan) (0..1). */
export function iqParticipation(c: Ctx): number | null {
  if (c.grade < 3) return null;
  return clamp(0.3 + 0.32 * (c.L.digital - 0.6) + 0.012 * c.t + signedNoise('iqp', c.key) * 0.05 + (c.grade >= 9 ? 0.04 : 0), 0.12, 0.8);
}

/** Qatlam standart ballari o'rtachasi (yosh normasi bo'yicha — sinfga bog'liq emas). */
export function iqMean(c: Ctx): number | null {
  if (c.grade < 3) return null;
  const typeFx = c.type === 'SPECIAL' ? 6 : c.type === 'PRIVATE' ? 2.5 : 0;
  return 100 + 3.4 * (c.L.resource - 0.58) + 1.2 * (c.L.urban - 0.5) + signedNoise('iq', c.key) * 0.9 + typeFx;
}

export const IQ_SD = 14.6;

/** Standart normal taqsimot funksiyasi (Abramowitz–Stegun). */
export function normCdf(z: number): number {
  const t = 1 / (1 + 0.2316419 * Math.abs(z));
  const d = 0.3989423 * Math.exp((-z * z) / 2);
  const p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
  return z > 0 ? 1 - p : p;
}

/** Band ulushlari (yig'indisi 1). */
export function iqBandShares(mu: number): Record<IqBand, number> {
  return Object.fromEntries(
    IQ_BANDS.map((band) => {
      const [lo, hi] = IQ_BAND_RANGES[band];
      const pHi = Number.isFinite(hi) ? normCdf((hi - mu) / IQ_SD) : 1;
      const pLo = Number.isFinite(lo) ? normCdf((lo - mu) / IQ_SD) : 0;
      return [band, pHi - pLo];
    }),
  ) as Record<IqBand, number>;
}

/** Yo'nalish bo'yicha to'g'ri javoblar % (aralash forma). */
export function iqDomainPercent(c: Ctx, domain: IqDomain): number | null {
  const mu = iqMean(c);
  if (mu === null) return null;
  const math = mastery(c, 'MATH') ?? 60;
  const native = mastery(c, 'NATIVE') ?? 66;
  const d = mu - 100;
  switch (domain) {
    case 'FIGURAL':
      return clamp(61 + 0.28 * d, 25, 95);
    case 'NUMERIC':
      return clamp(53 + 0.3 * d + 0.16 * (math - 60), 20, 95);
    case 'VERBAL':
      return clamp(57 + 0.25 * d + 0.14 * (native - 66), 20, 95);
    default:
      return clamp(50 + 0.32 * d, 20, 95);
  }
}

// ───────────────────────────── Farovonlik va muammolar ─────────────────────────────

const WB_SEASON: Record<number, number> = { 9: 1, 10: 0.5, 11: 0, 12: -0.5, 1: -2, 2: -1, 3: 0.5, 4: 0.8, 5: 0.6 };

export function wellbeingTopic(c: Ctx, topic: WellbeingTopic): number {
  const g = c.grade;
  const f = isF(c);
  const climate = c.L.climate - 0.65;
  let v: number;
  switch (topic) {
    case 'WELLBEING':
      v = 70 + 18 * climate - (inRange(g, 7, 9) ? 4 : g >= 10 ? 3 : 0) - 3 * (c.L.digital - 0.6) + (c.type === 'PRIVATE' ? 2 : 0);
      break;
    case 'LEARNING':
      v = 70 + 10 * (c.L.resource - 0.55) - (g >= 10 ? 5 : inRange(g, 7, 9) ? 2 : 0);
      break;
    case 'PEERS':
      v = 72 + 14 * climate - (inRange(g, 6, 8) ? 4 : 0) + (f ? 1 : -1);
      break;
    case 'SAFETY':
      v = 76 + 12 * climate - (inRange(g, 6, 8) ? 3 : 0);
      break;
    default:
      v = 64 + 10 * climate + (f ? 2 : -2) - (g >= 8 ? 2 : 0);
  }
  return clamp(v + (WB_SEASON[c.month] ?? 0) + signedNoise('wb', c.key, topic) * 2.2 + 0.03 * c.t, 35, 92);
}

/** Bulling signali: tazyiq savollariga "ko'pincha/ha" deb javob berganlar (%). */
export function bullying(c: Ctx): number {
  const g = c.grade;
  const gradeFx = inRange(g, 6, 8) ? 4 : g >= 9 ? 1 : g <= 4 ? -2 : 0;
  return clamp(10 - 18 * (c.L.climate - 0.65) + gradeFx + (isF(c) ? -1 : 1.5) + 3 * (c.L.digital - 0.6) + signedNoise('bul', c.key) * 1.6 - 0.04 * c.t, 2.5, 24);
}

/** Kelajak qo'llab-quvvatlash signali: "support" (≥2 xavotirli javob) (%). */
export function supportSignal(c: Ctx): number {
  return clamp(3.2 - 6 * (c.L.climate - 0.65) + (c.grade >= 8 ? 1 : 0) + (isF(c) ? 0.4 : 0) + signedNoise('sup', c.key) * 0.6, 0.8, 9);
}

/** Kelajak "watch" (1 xavotirli javob) (%). */
export function watchSignal(c: Ctx): number {
  return clamp(10 - 10 * (c.L.climate - 0.65) + (c.grade >= 8 ? 2 : 0) + signedNoise('wat', c.key) * 1.2, 4, 20);
}

/** Xavotir skriningi: WATCH + SUPPORT (%). */
export function anxiety(c: Ctx): number {
  const g = c.grade;
  return clamp(13 - 14 * (c.L.climate - 0.65) + (g >= 9 ? 4 : inRange(g, 7, 8) ? 2 : 0) + (isF(c) ? 2 : 0) + signedNoise('anx', c.key) * 1.4, 4, 28);
}

/** Yetarli uxlamaganlar (so'rovnomadagi uyqu savoli) (%). */
export function sleepShort(c: Ctx): number {
  const g = c.grade;
  return clamp(22 + 14 * (c.L.digital - 0.6) + (g >= 9 ? 10 : g >= 6 ? 4 : 0) + signedNoise('slp', c.key) * 2 + (c.month === 1 || c.month === 12 ? 2 : 0), 8, 48);
}

/** Psixologga murojaatlar — 1000 o'quvchiga oyiga. */
export function careRequests(c: Ctx): number {
  return clamp(6.5 + 4 * (c.L.urban - 0.5) + 3 * (c.L.climate - 0.65) + (c.grade >= 7 ? 1.5 : 0) + signedNoise('crq', c.key) * 1 + 0.05 * c.t, 2, 16);
}

const CARE_TOPIC_BASE: Record<CareTopic, number> = {
  LEARNING: 0.27, PEERS: 0.18, EMOTIONS: 0.17, FAMILY: 0.12, BULLYING: 0.1, SAFETY: 0.05, OTHER: 0.11,
};

export function careTopicShares(c: Ctx): Record<CareTopic, number> {
  const g = c.grade;
  const raw = Object.fromEntries(
    CARE_TOPICS.map((topic) => {
      let v = CARE_TOPIC_BASE[topic];
      if (topic === 'LEARNING' && g >= 9) v += 0.06;
      if (topic === 'EMOTIONS' && g >= 9) v += 0.03;
      if ((topic === 'PEERS' || topic === 'BULLYING') && inRange(g, 6, 8)) v += 0.03;
      if (topic === 'FAMILY' && g <= 5) v += 0.03;
      if (topic === 'BULLYING') v += 0.1 * (0.65 - c.L.climate);
      return [topic, Math.max(0.01, v + signedNoise('ct', c.key, topic) * 0.01)];
    }),
  ) as Record<CareTopic, number>;
  const total = Object.values(raw).reduce((a, b) => a + b, 0);
  return Object.fromEntries(CARE_TOPICS.map((k) => [k, raw[k] / total])) as Record<CareTopic, number>;
}

/** Shoshilinch murojaatlar ulushi (%). */
export function urgentShare(c: Ctx): number {
  return clamp(7 + signedNoise('urg', c.key) * 2 + (c.grade >= 8 ? 1 : 0), 3, 13);
}

/** SOS signallari — 1000 bolaga oyiga (faqat ota-ona ulangan qurilmalar). */
export function sosRate(c: Ctx): number {
  return clamp(0.55 + 0.5 * (c.L.urban - 0.5) + signedNoise('sos', c.key) * 0.15, 0.2, 1.4);
}

/** Xavfsizlik qoidalari bo'yicha bilim kamchiligi (Kelajak `safety_rules`) (%). */
export function safetyGap(c: Ctx): number {
  return clamp(22 - 10 * (c.L.resource - 0.55) - (c.grade >= 7 ? 4 : 0) + signedNoise('sg', c.key) * 2 - 0.05 * c.t, 6, 34);
}

export function schoolQuality(c: Ctx): number {
  return clamp(68 + 14 * (c.L.resource - 0.55) + signedNoise('sq', c.key) * 2.5 + (c.type === 'PRIVATE' ? 4 : 0), 45, 90);
}

export function teacherRelation(c: Ctx): number {
  return clamp(72 + 10 * (c.L.climate - 0.65) + signedNoise('trl', c.key) * 2.5 - (c.grade >= 9 ? 2 : 0), 50, 92);
}

// ───────────────────────────── Davomat ─────────────────────────────

const ATT_SEASON: Record<number, number> = { 9: 0.8, 10: 0.5, 11: -0.2, 12: -0.7, 1: -1.9, 2: -1.3, 3: -0.6, 4: 0.1, 5: -0.4 };

/** Davomat darajasi: (keldi + kechikdi + erta ketdi) / belgilangan kunlar (%). */
export function attendance(c: Ctx): number {
  return clamp(
    95.6 + 2.4 * (c.L.resource - 0.55) + 1.2 * (c.L.climate - 0.65) - (c.grade >= 10 ? 1.1 : 0) + (ATT_SEASON[c.month] ?? 0) +
      (c.type === 'PRIVATE' ? 0.8 : 0) + (isF(c) ? 0.3 : -0.3) + signedNoise('att', c.key) * 0.5 + 0.015 * c.t,
    86,
    99.3,
  );
}

/** Kechikish (%). */
export function late(c: Ctx): number {
  return clamp(6.5 - 4 * (c.L.resource - 0.55) + 2 * (c.L.urban - 0.5) + (c.grade >= 9 ? 1.2 : 0) + (c.month === 1 || c.month === 2 ? 1 : 0) + signedNoise('late', c.key) * 0.8, 1.5, 13);
}

/** Surunkali kelmaslik: kunlarning ≥10% ida kelmagan o'quvchilar (%). */
export function chronicAbsence(c: Ctx): number {
  return clamp(2 + 1.55 * (100 - attendance(c)) + signedNoise('chr', c.key) * 0.6, 1, 18);
}

/** Erta ketishlar — 100 o'quvchi-kunga. */
export function earlyExits(c: Ctx): number {
  return clamp(0.9 + signedNoise('ee', c.key) * 0.3 + (c.grade <= 4 ? 0.2 : 0), 0.3, 1.8);
}

export const WEEKDAY_FX = [-0.4, 0.2, 0.3, 0.2, -0.2, -1.2] as const;

// ───────────────────────────── Raqamli odatlar ─────────────────────────────

const SCREEN_SEASON: Record<number, number> = { 9: -10, 10: -4, 11: 0, 12: 8, 1: 15, 2: 6, 3: 0, 4: -4, 5: -8 };

/** O'quv kunidagi ekran vaqti (daqiqa). */
export function screenSchoolDay(c: Ctx): number {
  return clamp(
    150 + 70 * (c.L.digital - 0.6) - 60 + 14 * (c.grade - 1) + (isF(c) ? -8 : 12) + (SCREEN_SEASON[c.month] ?? 0) - 0.6 * c.t + signedNoise('scr', c.key) * 8,
    50,
    380,
  );
}

/** O'rtacha kunlik ekran vaqti (o'quv va dam olish kunlari aralash). */
export function screenTime(c: Ctx): number {
  const sd = screenSchoolDay(c);
  return 0.72 * sd + 0.28 * sd * 1.42;
}

export function appCategoryShares(c: Ctx): Record<AppCategory, number> {
  const g = c.grade;
  const f = isF(c);
  const raw: Record<AppCategory, number> = {
    VIDEO: 0.34 + (g <= 4 ? 0.1 : 0),
    GAME: 0.26 + (f ? -0.08 : 0.08) - (g >= 10 ? 0.05 : 0),
    SOCIAL: 0.2 + (g >= 8 ? 0.1 : g <= 4 ? -0.15 : 0) + (f ? 0.03 : 0),
    EDU: 0.09 + 0.03 * Math.min(1, c.t / 24) + (g <= 4 ? 0.03 : 0),
    OTHER: 0.11,
  };
  const total = APP_CATEGORIES.reduce((s, k) => s + Math.max(0.01, raw[k]), 0);
  return Object.fromEntries(APP_CATEGORIES.map((k) => [k, Math.max(0.01, raw[k]) / total])) as Record<AppCategory, number>;
}

/** Tungi (22:00–06:00) foydalanish ulushi (%). */
export function nightUse(c: Ctx): number {
  const g = c.grade;
  return clamp(6 + (g >= 10 ? 9 : g >= 7 ? 5 : g >= 5 ? 2 : 0) + 4 * (c.L.digital - 0.6) + (isF(c) ? 0 : 1) + signedNoise('ngt', c.key) * 1.2 - 0.03 * c.t, 1.5, 24);
}

/** Dars rejimiga rioya (qulflangan dars soatlari) (%). */
export function schoolModeCompliance(c: Ctx): number {
  return clamp(84 + 8 * (c.L.resource - 0.55) + (c.type === 'PRIVATE' ? 3 : 0) + signedNoise('smc', c.key) * 2 + 0.08 * c.t, 65, 98);
}

const STEPS_SEASON: Record<number, number> = { 9: 400, 10: 200, 11: -300, 12: -700, 1: -900, 2: -700, 3: 0, 4: 400, 5: 600 };

/** Kunlik qadamlar (mediana). */
export function steps(c: Ctx): number {
  return clamp(7200 - 2000 * (c.L.urban - 0.5) - (c.grade >= 9 ? 600 : 0) + (isF(c) ? -300 : 500) + (STEPS_SEASON[c.month] ?? 0) + signedNoise('stp', c.key) * 350, 3500, 11000);
}

export function moodShares(c: Ctx): Record<Mood, number> {
  const climate = c.L.climate - 0.65;
  const older = c.grade >= 9;
  const raw: Record<Mood, number> = {
    HAPPY: 0.3 + 0.3 * climate,
    EXCITED: 0.14,
    LOVE: 0.09,
    WINKING: 0.07,
    THINKING: 0.13 + (older ? 0.02 : 0),
    TIRED: 0.12 + (older ? 0.04 : 0) + 0.004 * (nightUse(c) - 8),
    SAD: 0.08 - 0.12 * climate,
    ANGRY: 0.06 + (c.grade >= 7 && c.grade <= 9 ? 0.01 : 0),
  };
  const total = MOODS.reduce((s, k) => s + Math.max(0.01, raw[k]), 0);
  return Object.fromEntries(MOODS.map((k) => [k, Math.max(0.01, raw[k]) / total])) as Record<Mood, number>;
}

/** Soatbay foydalanish profili (24 qiymat, yig'indisi 1). */
export function hourlyProfile(c: Ctx): number[] {
  const night = nightUse(c) / 100;
  const compliance = schoolModeCompliance(c) / 100;
  const raw = Array.from({ length: 24 }, (_, h) => {
    if (h >= 22 || h < 6) return night / 8;
    if (h >= 8 && h < 13) return (0.012 * (1 - compliance) + 0.004) * (h === 12 ? 1.6 : 1);
    if (h === 6 || h === 7) return 0.03;
    if (h >= 13 && h < 17) return 0.06;
    if (h >= 17 && h < 19) return 0.07;
    return 0.1;
  });
  const total = raw.reduce((a, b) => a + b, 0);
  return raw.map((v) => v / total);
}

export { APP_CATEGORIES, CARE_TOPICS, INTERESTS, MOODS, RIASEC, SUBJECT_KEYS };
