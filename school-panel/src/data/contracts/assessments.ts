import type { Id, IsoDate, IsoDateTime } from './common';

/**
 * Psixologik testlar (skrining, tashxis emas). Natijada faqat xom ball saqlanadi —
 * standart ball (100±15), persentil va daraja o'qilganda me'yorlar bo'yicha hisoblanadi.
 */
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
  key: string; // /^[A-Za-z][A-Za-z0-9_]{0,23}$/
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
/** scaleKey → yosh bandlari bo'yicha me'yor (demo me'yorlar, tahrirlanadi). */
export type PsychNorms = Record<string, NormRow[]>;
export type BandText = { label: Localized; advice: Localized };

export type PsychTest = {
  id: Id;
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
  createdBy: Id | null;
  updatedAt: IsoDateTime;
  basedOn: Id | null;
};
/** Shablonlar kodda; maktabga xos holat va me'yor o'zgarishlari shu yerda. */
export type TemplateState = { status: PsychTestStatus; norms: PsychNorms | null };

export type AssignmentTarget = { kind: 'CLASSES'; classIds: Id[] } | { kind: 'GRADES'; grades: number[] };
export type PsychAssignment = {
  id: Id;
  testId: Id;
  testVersion: number;
  target: AssignmentTarget;
  /** Yaratilganda aniqlangan sinflar (doira tekshiruvi shu bo'yicha). */
  classIds: Id[];
  opensAt: IsoDateTime;
  closesAt: IsoDateTime;
  status: 'OPEN' | 'CLOSED' | 'CANCELLED';
  invited: number;
  consent: 'PARENTS_INFORMED';
  createdBy: Id;
  createdAt: IsoDateTime;
};
export type AssignmentState = 'SCHEDULED' | 'ACTIVE' | 'ENDED' | 'CANCELLED';

export type PsychResultOrigin = 'SEED' | 'APP' | 'IMPORT' | 'MANUAL';
export type PsychResult = {
  id: Id;
  studentId: Id;
  classId: Id;
  grade: number;
  ageBand: AgeBand;
  testId: Id;
  version: number;
  assignmentId: Id | null;
  takenAt: IsoDateTime;
  origin: PsychResultOrigin;
  /** scaleKey → xom ball (YAGONA saqlanadigan ball). */
  raw: Record<string, number>;
  /** Ixcham: har savolga 1 belgi (encodeAnswers). */
  answers?: string;
  durationSec?: number;
};
export type ScaleScore = {
  key: string;
  raw: number;
  max: number | null;
  z: number | null;
  standard: number | null;
  percentile: number | null;
  band: ScoreBand | null;
};
export type ScoredResult = PsychResult & { scales: ScaleScore[]; topCodes: string | null };

/** O'tgan choraklar tarixi saqlanmaydi — shu konfiguratsiyadan deterministik hisoblanadi. */
export type HistoryWave = { key: string; date: IsoDate; testIds: TemplateId[] };
export type PsychHistoryConfig = { seed: number; waves: HistoryWave[] };
