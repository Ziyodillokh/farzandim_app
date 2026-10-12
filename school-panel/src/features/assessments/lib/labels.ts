import { Brain, Compass, Eye, FlaskConical, HeartPulse, type LucideIcon, Sparkles, Users } from 'lucide-react';

import type { BadgeProps } from '@/components/ui/badge';
import type { AssignmentState, PsychTestKind, PsychTestSource, PsychTestStatus, ScoreBand } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import type { TKey } from '@/i18n';
import { errorKey } from '@/lib/errors';

type Variant = NonNullable<BadgeProps['variant']>;
type T = (key: TKey, vars?: Record<string, string | number>) => string;

export const KIND_ICON: Record<PsychTestKind, LucideIcon> = {
  COGNITIVE: Brain,
  ATTENTION: Eye,
  EMOTIONAL: HeartPulse,
  SELF_ESTEEM: Sparkles,
  CAREER: Compass,
  SOCIAL: Users,
  CUSTOM: FlaskConical,
};

/** Faqat ko'k / moviy / zangori aksentlar. */
export const KIND_TONE: Record<PsychTestKind, string> = {
  COGNITIVE: 'bg-primary/10 text-primary ring-primary/20',
  ATTENTION: 'bg-sky-500/10 text-sky-600 ring-sky-500/20 dark:text-sky-300',
  EMOTIONAL: 'bg-cyan-500/10 text-cyan-700 ring-cyan-500/20 dark:text-cyan-300',
  SELF_ESTEEM: 'bg-blue-500/10 text-blue-600 ring-blue-500/20 dark:text-blue-300',
  CAREER: 'bg-sky-500/10 text-sky-700 ring-sky-500/20 dark:text-sky-300',
  SOCIAL: 'bg-cyan-500/10 text-cyan-700 ring-cyan-500/20 dark:text-cyan-300',
  CUSTOM: 'bg-primary/10 text-primary ring-primary/20',
};

export const SOURCE_VARIANT: Record<PsychTestSource, Variant> = { TEMPLATE: 'default', CUSTOM: 'info', IMPORTED: 'info', EXTERNAL: 'outline' };
export const STATUS_VARIANT: Record<PsychTestStatus, Variant> = { DRAFT: 'secondary', PUBLISHED: 'success', ARCHIVED: 'outline' };
export const STATE_VARIANT: Record<AssignmentState, Variant> = { SCHEDULED: 'info', ACTIVE: 'success', ENDED: 'secondary', CANCELLED: 'outline' };

export const BAND_VARIANT: Record<ScoreBand, Variant> = {
  VERY_LOW: 'warning',
  LOW: 'secondary',
  AVERAGE: 'default',
  HIGH: 'info',
  VERY_HIGH: 'success',
  TYPICAL: 'success',
  WATCH: 'warning',
  SUPPORT: 'destructive',
};

const CONCERN = new Set<string>(['TYPICAL', 'WATCH', 'SUPPORT']);
export const isConcernBand = (band: string) => CONCERN.has(band);

/** Gistogramma: ko'k soyalar (ochdan to'qqa). */
const SHADES = ['hsl(199 92% 74%)', 'hsl(204 90% 62%)', 'hsl(214 92% 56%)', 'hsl(221 86% 47%)', 'hsl(225 78% 37%)', 'hsl(189 80% 42%)'];
const FALLBACK_SHADE = 'hsl(214 92% 56%)';
export function bandColor(index: number, total: number): string {
  const shade = total <= 3 ? [1, 3, 4][index] : index % SHADES.length;
  return SHADES[shade ?? 2] ?? FALLBACK_SHADE;
}

export function bandLabel(t: T, band: ScoreBand, short = false): string {
  if (short) return t(`assessments.bandShort.${band}`);
  return isConcernBand(band) ? t(`enums.concernBand.${band as 'TYPICAL'}`) : t(`enums.abilityBand.${band as 'AVERAGE'}`);
}

/** [3..11] → "3–11-sinflar"; [7] → "7-sinf"; uzilishli — vergul bilan. */
export function gradesLabel(t: T, grades: readonly number[]): string {
  const sorted = [...grades].sort((a, b) => a - b);
  const first = sorted[0];
  const last = sorted.at(-1);
  if (first === undefined || last === undefined) return '—';
  if (first === last) return t('assessments.gradeOne', { grade: first });
  if (last - first + 1 === sorted.length) return t('assessments.gradesRange', { from: first, to: last });
  return sorted.join(', ');
}

const VALIDATION_KEY = /assessments\.validation\.[A-Za-z]+|errors\.form\.[A-Za-z]+/;

/** Servis xatosi → tarjima kaliti (`assessments.validation.*` ham). */
export function psychErrorKey(error: unknown): TKey {
  if (error instanceof ServiceError && error.code === 'VALIDATION') {
    const match = VALIDATION_KEY.exec(error.message)?.[0];
    if (match) return match as TKey;
  }
  return errorKey(error);
}

/** Zod xabari (i18n kaliti bo'lsa) → matn. */
export function fieldMessage(t: T, message: string | undefined): string | undefined {
  if (!message) return undefined;
  return message.startsWith('errors.') || message.startsWith('assessments.') ? t(message as TKey) : message;
}

/** `datetime-local` qiymati: "YYYY-MM-DDTHH:MM". */
export function toLocalInput(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
