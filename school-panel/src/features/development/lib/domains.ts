import type { AbilityBand, DevDomain, ScoreBand } from '@/data/contracts';
import type { TKey } from '@/i18n';

/** Sohalar tartibi (radar o'qlari, jadval ustunlari, grafik qatorlari). */
export const DOMAINS: readonly DevDomain[] = ['REASONING', 'ATTENTION', 'MEMORY', 'EMOTIONAL', 'SELF_ESTEEM', 'SOCIAL'];
export const ABILITY_BANDS: readonly AbilityBand[] = ['VERY_LOW', 'LOW', 'AVERAGE', 'HIGH', 'VERY_HIGH'];

/**
 * Faqat ko'k / osmon / feruza (brend). 6 soha 3 rangda — ikkinchi kodlash: kognitiv sohalar
 * yaxlit, ijtimoiy-hissiy sohalar uzuq chiziq (legenda doim bor, rang yolg'iz emas).
 */
export const DOMAIN_STYLE: Record<DevDomain, { color: string; dash?: string }> = {
  REASONING: { color: 'hsl(var(--primary))' },
  ATTENTION: { color: 'hsl(var(--info))' },
  MEMORY: { color: 'hsl(var(--chart-5))' },
  EMOTIONAL: { color: 'hsl(var(--primary))', dash: '5 4' },
  SELF_ESTEEM: { color: 'hsl(var(--info))', dash: '5 4' },
  SOCIAL: { color: 'hsl(var(--chart-5))', dash: '5 4' },
};

/** Tartibli darajalar — ketma-ket osmon → ko'k shkala (qizil yo'q). */
export const BAND_FILL: Record<AbilityBand, string> = {
  VERY_LOW: 'hsl(199 78% 80%)',
  LOW: 'hsl(202 82% 66%)',
  AVERAGE: 'hsl(209 84% 55%)',
  HIGH: 'hsl(218 82% 47%)',
  VERY_HIGH: 'hsl(226 72% 36%)',
};

/** Issiqlik xaritasi: 0..100 → osmon (och) … ko'k (to'q); yorug' va qorong'i fonda ishlaydi. */
const HEAT_LOW = 25;
const HEAT_HIGH = 75;

export function heatStyle(index: number): { background: string; color: string } {
  // O'rtachalar odatda 25..75 oralig'ida — shkala shu oraliqqa cho'ziladi (aks holda hammasi bir xil).
  const x = Math.min(1, Math.max(0, (index - HEAT_LOW) / (HEAT_HIGH - HEAT_LOW)));
  const hue = 199 + 25 * x;
  const alpha = 0.12 + 0.78 * x;
  return { background: `hsl(${hue.toFixed(0)} 82% 48% / ${alpha.toFixed(2)})`, color: alpha > 0.55 ? 'hsl(0 0% 100%)' : 'hsl(var(--foreground))' };
}

/** Chip ohangi: barcha darajalar ko'k oilasida, past darajalar — e'tiborli, lekin qo'rqituvchi emas. */
export function bandTone(band: ScoreBand | null): string {
  switch (band) {
    case 'VERY_LOW':
    case 'SUPPORT':
      return 'bg-sky-500/15 text-sky-800 ring-sky-600/35 dark:text-sky-200';
    case 'LOW':
    case 'WATCH':
      return 'bg-sky-500/10 text-sky-700 ring-sky-500/25 dark:text-sky-300';
    case 'HIGH':
      return 'bg-primary/10 text-primary ring-primary/20';
    case 'VERY_HIGH':
      return 'bg-primary/15 text-primary ring-primary/30';
    case 'AVERAGE':
    case 'TYPICAL':
      return 'bg-white/60 text-foreground/80 ring-border dark:bg-white/[0.04]';
    default:
      return 'bg-muted text-muted-foreground ring-border';
  }
}

export const domainKey = (d: DevDomain): TKey => `enums.devDomain.${d}`;
export const bandShortKey = (b: ScoreBand): TKey => `development.bandShort.${b}`;
export const adviceKey = (b: ScoreBand): TKey => `development.advice.${b}`;
export const bandLongKey = (b: ScoreBand): TKey =>
  b === 'TYPICAL' || b === 'WATCH' || b === 'SUPPORT' ? `enums.concernBand.${b}` : `enums.abilityBand.${b}`;

/** "2025-26:Q4" → "2025–26, 4-chorak". */
export function formatTerm(termKey: string, t: (key: TKey, vars?: Record<string, string | number>) => string): string {
  const match = termKey.match(/^(\d{4})-(\d{2}):Q([1-4])$/);
  if (!match) return termKey;
  return t('development.term.value', { year: `${match[1]}–${match[2]}`, no: Number(match[3]) });
}

/** Qisqa: "Q4 25–26". */
export function shortTerm(termKey: string): string {
  const match = termKey.match(/^\d{2}(\d{2})-(\d{2}):Q([1-4])$/);
  return match ? `Q${match[3]} ${match[1]}–${match[2]}` : termKey;
}
