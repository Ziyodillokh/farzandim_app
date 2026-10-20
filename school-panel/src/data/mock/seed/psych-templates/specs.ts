import type { AgeBand, Localized, NormRow, PsychScale, PsychTestKind, TemplateId } from '@/data/contracts';

/**
 * Test shablonlari spetsifikatsiyasi — shkalalar, xom ball oralig'i va DEMO me'yorlar.
 * Savollar kontenti alohida fayllarda (agent A). Me'yorlar sintetik ("demo me'yorlar"),
 * hech qanday nashr etilgan testdan olinmagan.
 */
export type TemplateSpec = {
  id: TemplateId;
  kind: PsychTestKind;
  title: Localized;
  grades: number[];
  timeLimitMin: number;
  scales: PsychScale[];
  /** scaleKey → xom ball oralig'i (savollar soni bilan mos bo'lishi test bilan tekshiriladi). */
  ranges: Record<string, { min: number; max: number }>;
  norms: Record<string, NormRow[]>;
};

const BANDS: AgeBand[] = ['A7_8', 'A9_10', 'A11_12', 'A13_14', 'A15_17'];
function norms(rows: Array<[number, number] | null>): NormRow[] {
  return rows.flatMap((r, i) => (r ? [{ band: BANDS[i] as AgeBand, mean: r[0], sd: r[1] }] : []));
}
const L = (uz: string, ru: string): Localized => ({ uz, ru });
const range = (lo: number, hi: number) => (lo <= hi ? Array.from({ length: hi - lo + 1 }, (_, i) => lo + i) : []);

export const TEMPLATE_SPECS: Record<TemplateId, TemplateSpec> = {
  'tpl-logic': {
    id: 'tpl-logic',
    kind: 'COGNITIVE',
    title: L('Mantiqiy fikrlash', 'Логическое мышление'),
    grades: range(3, 11),
    timeLimitMin: 20,
    scales: [{ key: 'total', label: L('Mantiqiy fikrlash indeksi', 'Индекс логического мышления'), domain: 'REASONING', polarity: 'HIGHER_BETTER', display: 'STANDARD' }],
    ranges: { total: { min: 0, max: 16 } },
    norms: { total: norms([[5.6, 2.7], [7.0, 2.9], [8.6, 2.9], [10.2, 2.8], [11.6, 2.6]]) },
  },
  'tpl-attention': {
    id: 'tpl-attention',
    kind: 'ATTENTION',
    title: L('Diqqat va xotira', 'Внимание и память'),
    grades: range(3, 11),
    timeLimitMin: 15,
    scales: [
      { key: 'attention', label: L('Diqqat', 'Внимание'), domain: 'ATTENTION', polarity: 'HIGHER_BETTER', display: 'STANDARD' },
      { key: 'memory', label: L('Xotira', 'Память'), domain: 'MEMORY', polarity: 'HIGHER_BETTER', display: 'STANDARD' },
    ],
    ranges: { attention: { min: 0, max: 7 }, memory: { min: 0, max: 7 } },
    norms: {
      attention: norms([[3.6, 1.6], [4.2, 1.5], [4.7, 1.4], [5.1, 1.3], [5.4, 1.2]]),
      memory: norms([[3.3, 1.6], [3.9, 1.6], [4.4, 1.5], [4.8, 1.4], [5.1, 1.3]]),
    },
  },
  'tpl-emotion': {
    id: 'tpl-emotion',
    kind: 'EMOTIONAL',
    title: L('Hissiy holat skriningi', 'Скрининг эмоционального состояния'),
    grades: range(3, 11),
    timeLimitMin: 10,
    scales: [
      { key: 'worry', label: L('Xavotir', 'Тревожность'), domain: 'EMOTIONAL', polarity: 'HIGHER_CONCERN', display: 'LEVEL' },
      { key: 'mood', label: L('Kayfiyat', 'Настроение'), domain: 'EMOTIONAL', polarity: 'HIGHER_BETTER', display: 'LEVEL' },
    ],
    ranges: { worry: { min: 7, max: 35 }, mood: { min: 5, max: 25 } },
    norms: {
      worry: norms([[15.5, 5.0], [16.0, 5.0], [16.8, 5.2], [17.8, 5.5], [18.5, 5.6]]),
      mood: norms([[19.5, 3.4], [19.2, 3.5], [18.8, 3.6], [18.3, 3.8], [18.0, 3.9]]),
    },
  },
  'tpl-self': {
    id: 'tpl-self',
    kind: 'SELF_ESTEEM',
    title: L('O\'zimga ishonch', 'Уверенность в себе'),
    grades: range(5, 11),
    timeLimitMin: 8,
    scales: [{ key: 'self', label: L('O\'ziga ishonch', 'Уверенность в себе'), domain: 'SELF_ESTEEM', polarity: 'HIGHER_BETTER', display: 'PERCENTILE' }],
    ranges: { self: { min: 10, max: 50 } },
    norms: { self: norms([null, [36.5, 6.0], [36.0, 6.0], [35.0, 6.5], [35.5, 6.5]]) },
  },
  'tpl-career': {
    id: 'tpl-career',
    kind: 'CAREER',
    title: L('Kasbiy qiziqishlar', 'Профессиональные интересы'),
    grades: range(8, 11),
    timeLimitMin: 10,
    scales: [
      { key: 'R', label: L('Amaliy-texnik', 'Практико-технический'), domain: null, polarity: 'HIGHER_BETTER', display: 'RAW' },
      { key: 'I', label: L('Tadqiqotchi', 'Исследовательский'), domain: null, polarity: 'HIGHER_BETTER', display: 'RAW' },
      { key: 'A', label: L('Ijodiy', 'Творческий'), domain: null, polarity: 'HIGHER_BETTER', display: 'RAW' },
      { key: 'S', label: L('Ijtimoiy', 'Социальный'), domain: null, polarity: 'HIGHER_BETTER', display: 'RAW' },
      { key: 'E', label: L('Tashabbuskor', 'Предприимчивый'), domain: null, polarity: 'HIGHER_BETTER', display: 'RAW' },
      { key: 'C', label: L('Tartib va hujjat', 'Порядок и документы'), domain: null, polarity: 'HIGHER_BETTER', display: 'RAW' },
    ],
    ranges: { R: { min: 0, max: 6 }, I: { min: 0, max: 6 }, A: { min: 0, max: 6 }, S: { min: 0, max: 6 }, E: { min: 0, max: 6 }, C: { min: 0, max: 6 } },
    norms: {},
  },
  'tpl-social': {
    id: 'tpl-social',
    kind: 'SOCIAL',
    title: L('Ijtimoiy ko\'nikmalar', 'Социальные навыки'),
    grades: range(3, 8),
    timeLimitMin: 8,
    scales: [{ key: 'social', label: L('Ijtimoiy ko\'nikmalar', 'Социальные навыки'), domain: 'SOCIAL', polarity: 'HIGHER_BETTER', display: 'PERCENTILE' }],
    ranges: { social: { min: 10, max: 50 } },
    norms: { social: norms([[36, 6], [37, 6], [37.5, 6], [37, 6.5], [37, 6.5]]) },
  },
};

export const TEMPLATE_IDS = Object.keys(TEMPLATE_SPECS) as TemplateId[];
