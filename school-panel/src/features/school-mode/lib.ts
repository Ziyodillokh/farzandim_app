import type { Tone } from '@/components/common/stat-card';
import { ServiceError } from '@/data/contracts';
import type { ClassModeState } from '@/data/mock/services/school-mode';
import type { TKey } from '@/i18n';
import { errorKey } from '@/lib/errors';

/** Servis xatosi → tarjima kaliti (modulga xos validatsiya xabarlari ham). */
export function smErrorKey(error: unknown): TKey {
  if (error instanceof ServiceError) {
    const key = error.message.split(': ')[1];
    if (key?.startsWith('schoolMode.validation.')) return key as TKey;
  }
  return errorKey(error);
}

/** Zod xabari (i18n kaliti) bo'lsa tarjima qilinadi. */
export function isMessageKey(message: string | undefined): message is TKey {
  return Boolean(message && (message.startsWith('errors.') || message.startsWith('schoolMode.')));
}

export type StateKind = ClassModeState['kind'];

/** Holat ranglari: dars — asosiy ko'k, tanaffus — info, favqulodda — qizil, qolgani — xira. */
export function stateTone(kind: StateKind): Tone {
  if (kind === 'LESSON') return 'primary';
  if (kind === 'BREAK') return 'info';
  if (kind === 'EMERGENCY_OFF') return 'destructive';
  return 'muted';
}

export const TONE_DOT: Record<Tone, string> = {
  primary: 'bg-primary',
  info: 'bg-info',
  destructive: 'bg-destructive',
  muted: 'bg-muted-foreground/50',
  success: 'bg-success',
  warning: 'bg-warning',
};

export const TONE_RING: Record<Tone, string> = {
  primary: 'border-primary/30 bg-primary/[0.04]',
  info: 'border-info/30 bg-info/[0.04]',
  destructive: 'border-destructive/40 bg-destructive/[0.05]',
  muted: 'border-border',
  success: 'border-success/30',
  warning: 'border-warning/30',
};

export type ExceptionPreset = 'm15' | 'lesson' | 'endOfDay' | 'custom';
export const EXCEPTION_PRESETS: readonly ExceptionPreset[] = ['m15', 'lesson', 'endOfDay', 'custom'];
const LESSON_MINUTES = 45;
const SHORT_MINUTES = 15;

/** Tanlangan muddat → "HH:MM" (bugun). Kun oxiri — 23:59. */
export function presetUntil(preset: ExceptionPreset, now: Date, custom: string): string {
  if (preset === 'custom') return custom;
  if (preset === 'endOfDay') return '23:59';
  const minutes = preset === 'm15' ? SHORT_MINUTES : LESSON_MINUTES;
  const at = new Date(now.getTime() + minutes * 60_000);
  const sameDay = at.getDate() === now.getDate();
  if (!sameDay) return '23:59';
  return `${String(at.getHours()).padStart(2, '0')}:${String(at.getMinutes()).padStart(2, '0')}`;
}

/** "YYYY-MM-DD" → mahalliy yarim tun (UTC siljishisiz). */
export function localDate(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1);
}
