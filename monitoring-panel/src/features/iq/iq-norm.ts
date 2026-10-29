import type { Iq } from '@/data/contracts';
import { IQ_DISPLAY_BANDS, type IqDisplayBand } from '@/data/reference/domains';

/**
 * Nazariy normal taqsimot (o'rtacha 100, SD 15) bo'yicha darajalarning kutilgan
 * ulushi, %. Masalan, 90–109 → 49,5%; 80 dan past → 9,1%.
 */
export const IQ_NORM_SHARE: Readonly<Record<IqDisplayBand, number>> = {
  VERY_HIGH: 2.3,
  HIGH: 6.8,
  ABOVE_AVERAGE: 16.1,
  AVERAGE: 49.5,
  BELOW_AVERAGE: 16.1,
  GROWTH_ZONE: 9.1,
};

/** Chapdan o'ngga — pastdan yuqoriga (taqsimot grafigi va yig'ma ustunlar uchun). */
export const IQ_BANDS_ASC: readonly IqDisplayBand[] = [...IQ_DISPLAY_BANDS].reverse();

/** Normadan farq shu chegaradan kichik bo'lsa — "normaga yaqin". */
export const NORM_CLOSE_PP = 2;

export function bandShare(bands: Iq['bands'], band: IqDisplayBand): number {
  return bands.find((b) => b.key === band)?.share ?? 0;
}

/** Eng katta ulushli daraja (norma shakllanmaganda o'rtacha ball o'rniga). */
export function modalBand(bands: Iq['bands']): Iq['bands'][number] | null {
  return bands.reduce<Iq['bands'][number] | null>((best, b) => (b.share > (best?.share ?? 0) ? b : best), null);
}

/** Normadan eng katta og'ish (p.p.) — qaysi darajada. */
export function maxNormDeviation(bands: Iq['bands']): { band: IqDisplayBand; diff: number } | null {
  if (bands.every((b) => b.share === 0)) return null;
  return IQ_DISPLAY_BANDS.map((band) => ({ band, diff: Math.round((bandShare(bands, band) - IQ_NORM_SHARE[band]) * 10) / 10 })).reduce((a, b) =>
    Math.abs(b.diff) > Math.abs(a.diff) ? b : a,
  );
}
