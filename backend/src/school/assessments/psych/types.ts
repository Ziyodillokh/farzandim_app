// Psixologik testlar — panel `school-panel/src/data/contracts/assessments.ts`
// bilan BIR XIL turlar (skrining, tashxis emas). Natijada faqat xom ball
// saqlanadi — standart ball (100±15), persentil va daraja o'qilganda me'yorlar
// bo'yicha hisoblanadi (me'yor o'zgarsa natijalar darhol qayta baholanadi).

export type IsoDate = string;
export type Localized = { uz: string; ru: string };
export type TemplateId = 'tpl-logic' | 'tpl-attention' | 'tpl-emotion' | 'tpl-self' | 'tpl-career' | 'tpl-social';
export type PsychTestKind = 'COGNITIVE' | 'ATTENTION' | 'EMOTIONAL' | 'SELF_ESTEEM' | 'CAREER' | 'SOCIAL' | 'CUSTOM';
/** EXTERNAL — faqat natijalari import qilinadigan tashqi test (masalan, qog'ozda o'tkazilgan). */
export type PsychTestSource = 'TEMPLATE' | 'CUSTOM' | 'IMPORTED' | 'EXTERNAL';
export type PsychTestStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
export type DevDomain = 'REASONING' | 'ATTENTION' | 'MEMORY' | 'EMOTIONAL' | 'SELF_ESTEEM' | 'SOCIAL';
export type AgeBand = 'A7_8' | 'A9_10' | 'A11_12' | 'A13_14' | 'A15_17';
export type ScalePolarity = 'HIGHER_BETTER' | 'HIGHER_CONCERN';
export type AbilityBand = 'VERY_LOW' | 'LOW' | 'AVERAGE' | 'HIGH' | 'VERY_HIGH';
export type ConcernBand = 'TYPICAL' | 'WATCH' | 'SUPPORT';
export type ScoreBand = AbilityBand | ConcernBand;
/** STANDARD — 100±15; PERCENTILE; LEVEL — faqat daraja (skrining); RAW — xom (kasbiy qiziqish). */
export type ScaleDisplay = 'STANDARD' | 'PERCENTILE' | 'LEVEL' | 'RAW';

export type PsychScale = {
  key: string;
  label: Localized;
  domain: DevDomain | null;
  polarity: ScalePolarity;
  display: ScaleDisplay;
};
export type ChoiceOption = { key: string; text: Localized };
export type Stimulus = { text: Localized; showSec: number };
export type PsychItem =
  | { id: string; type: 'SINGLE'; scale: string; text: Localized; options: ChoiceOption[]; correct: string; stimulus?: Stimulus }
  | { id: string; type: 'LIKERT'; scale: string; text: Localized; reverse: boolean }
  | { id: string; type: 'MULTI'; text: Localized; options: Array<ChoiceOption & { scale: string }> };

export type NormRow = { band: AgeBand; mean: number; sd: number };
/** scaleKey → yosh bandlari bo'yicha me'yor. */
export type PsychNorms = Record<string, NormRow[]>;
export type BandText = { label: Localized; advice: Localized };

export type PsychTest = {
  id: string;
  title: Localized;
  description: Localized;
  instructions: Localized;
  kind: PsychTestKind;
  source: PsychTestSource;
  grades: number[];
  timeLimitMin: number | null;
  scales: PsychScale[];
  items: PsychItem[];
  scoring: { method: 'SUM' | 'PERCENT_CORRECT' | 'PER_SCALE' };
  norms: PsychNorms;
  bandText?: Partial<Record<ScoreBand, BandText>>;
  version: number;
  status: PsychTestStatus;
  createdBy: string | null;
  updatedAt: string;
  basedOn: string | null;
};

/** Testning ko'chma qismi (konstruktor formasi, JSON eksport/import, nusxa). */
export type PsychTestInputShape = Pick<
  PsychTest,
  'title' | 'description' | 'instructions' | 'kind' | 'grades' | 'timeLimitMin' | 'scales' | 'items' | 'scoring' | 'norms'
>;

export type AssignmentTarget ={ kind: 'CLASSES'; classIds: string[] } | { kind: 'GRADES'; grades: number[] };
export type AssignmentStatus = 'OPEN' | 'CLOSED' | 'CANCELLED';
export type AssignmentState = 'SCHEDULED' | 'ACTIVE' | 'ENDED' | 'CANCELLED';
export type PsychResultOrigin = 'SEED' | 'APP' | 'IMPORT' | 'MANUAL';

export type ScaleScore = {
  key: string;
  raw: number;
  max: number | null;
  z: number | null;
  standard: number | null;
  percentile: number | null;
  band: ScoreBand | null;
};
