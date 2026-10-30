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

/** O'g'il va qiz bolalar o'rtacha bali farqi shundan kichik bo'lsa — amaliy ahamiyatga ega emas. */
export const GENDER_GAP_POINTS = 3;

export function bandShare(bands: Iq['bands'], band: IqDisplayBand): number {
  return bands.find((b) => b.key === band)?.share ?? 0;
}

/** Taqsimot bormi: hech bo'lmasa bitta daraja ulushi musbat (aks holda — "ma'lumot yo'q", 0% emas). */
export function hasBandData(bands: Iq['bands']): boolean {
  return bands.some((b) => b.share > 0);
}

/** Bo'linma (hudud/tuman) taqsimoti bormi: `null` yoki hamma ulush 0 — yo'q. */
export function hasAreaBands(bands: Iq['byArea'][number]['bands']): bands is Record<IqDisplayBand, number> {
  return bands !== null && IQ_DISPLAY_BANDS.some((b) => bands[b] > 0);
}

/** Eng katta ulushli daraja (norma shakllanmaganda o'rtacha ball o'rniga); taqsimot yo'q — null. */
export function modalBand(bands: Iq['bands']): Iq['bands'][number] | null {
  return bands.reduce<Iq['bands'][number] | null>((best, b) => (b.share > (best?.share ?? 0) ? b : best), null);
}

/** Normadan eng katta og'ish (p.p.) — qaysi darajada; taqsimot yo'q — null. */
export function maxNormDeviation(bands: Iq['bands']): { band: IqDisplayBand; diff: number } | null {
  if (!hasBandData(bands)) return null;
  return IQ_DISPLAY_BANDS.map((band) => ({ band, diff: Math.round((bandShare(bands, band) - IQ_NORM_SHARE[band]) * 10) / 10 })).reduce((a, b) =>
    Math.abs(b.diff) > Math.abs(a.diff) ? b : a,
  );
}

/** Norma bilan taqqoslash xulosasi: eng katta og'ish `NORM_CLOSE_PP` dan kichik — "yaqin", aks holda — "uzoq". */
export function normVerdict(bands: Iq['bands']): { kind: 'close' | 'far'; band: IqDisplayBand; diff: number } | null {
  const dev = maxNormDeviation(bands);
  if (!dev) return null;
  return { ...dev, kind: Math.abs(dev.diff) < NORM_CLOSE_PP ? 'close' : 'far' };
}
