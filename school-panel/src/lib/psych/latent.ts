import type { DevDomain } from '@/data/contracts';
import { hashString, mulberry32, unitHash } from '@/lib/rng';

/**
 * Demo "iste'dod" modeli — deterministik (xesh), korrelyatsiyali sohalar.
 * Tarix (agent B) va ilovadagi javob simulyatori (agent A) shu modeldan foydalanadi,
 * shuning uchun jonli natijalar tarix bilan mos keladi.
 */
export function normalFromHash(...parts: Array<string | number>): number {
  // Ikki mustaqil son bitta PRNG oqimidan: `unitHash(..., 'u1'|'u2')` faqat oxirgi belgida farq qilardi
  // (FNV-1a) — u2 ≈ u1 + const, Box–Muller dumlari buzilardi.
  const next = mulberry32(hashString(parts.join('|')));
  const u1 = Math.max(1e-9, next());
  const u2 = next();
  return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
}

/** Umumiy omil (g) ulushi — qolgani sohaga xos. */
const G_LOAD: Record<DevDomain, number> = {
  REASONING: 0.85,
  ATTENTION: 0.6,
  MEMORY: 0.6,
  EMOTIONAL: 0.2,
  SELF_ESTEEM: 0.3,
  SOCIAL: 0.25,
};

/** Sinf bo'yicha og'ishlar (SD birligida) — Care seed'idagi "zaif nuqtalar" bilan mos. */
export const CLASS_BIAS: Readonly<Record<string, Partial<Record<DevDomain, number>>>> = {
  'cls-8b': { EMOTIONAL: -0.45, SOCIAL: -0.4 },
  'cls-10b': { EMOTIONAL: -0.35 },
  'cls-6a': { ATTENTION: -0.35, REASONING: -0.15 },
  'cls-9a': { REASONING: 0.25 },
};

/** O'quvchining soha bo'yicha "haqiqiy" darajasi, z birligida (≈ N(0,1) + sinf og'ishi). */
export function latent(studentId: string, domain: DevDomain, classId?: string): number {
  const g = normalFromHash(studentId, 'g');
  const e = normalFromHash(studentId, domain);
  const load = G_LOAD[domain];
  const bias = classId ? (CLASS_BIAS[classId]?.[domain] ?? 0) : 0;
  return load * g + Math.sqrt(1 - load * load) * e + bias;
}

/** Chorakdan chorakka tebranish; ~5% o'quvchida oxirgi to'lqinda ~1 SD pasayish (e'tibor ro'yxati uchun). */
export function waveDrift(studentId: string, domain: DevDomain, wave: number, lastWave: number): number {
  const noise = 0.35 * normalFromHash(studentId, domain, 'wave', wave);
  const decliner = unitHash(studentId, 'decline') < 0.05 && wave === lastWave ? -1 : 0;
  return noise + decliner;
}
