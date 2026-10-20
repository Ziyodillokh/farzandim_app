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

/* ── Aurora shisha: karta ichidagi bo'laklar (to'liq nomlar — Tailwind skaneri uchun) ── */

/** Ichki plitka (shisha karta ichida). */
export const TILE = 'rounded-xl bg-white/50 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]';

/** Holat rangidagi ichki plitka foni va halqasi (`rounded-xl ring-1 ring-inset` bilan). */
export const TONE_TILE: Record<Tone, string> = {
  primary: 'bg-primary/[0.05] ring-primary/25 dark:bg-primary/[0.08]',
  info: 'bg-info/[0.06] ring-info/25 dark:bg-info/[0.08]',
  destructive: 'bg-destructive/[0.06] ring-destructive/35 dark:bg-destructive/[0.1]',
  muted: 'bg-white/50 ring-border/60 dark:bg-white/[0.03]',
  success: 'bg-success/[0.06] ring-success/25',
  warning: 'bg-warning/[0.07] ring-warning/30',
};

/** Ikonka "orb" — yumshoq rangli plitka (qattiq bg-primary emas). */
export const TONE_ORB: Record<Tone, string> = {
  primary: 'bg-primary/10 text-primary ring-primary/20',
  info: 'bg-info/10 text-info ring-info/25',
  destructive: 'bg-destructive/10 text-destructive ring-destructive/25',
  muted: 'bg-muted text-muted-foreground ring-border/60',
  success: 'bg-success/10 text-success ring-success/25',
  warning: 'bg-warning/15 text-warning ring-warning/25',
};

/** Segmentli boshqaruv: trek, faol va nofaol tugma. */
export const SEG_TRACK = 'rounded-xl bg-primary/[0.05] p-1 ring-1 ring-inset ring-border/60 dark:bg-white/[0.04]';
export const SEG_ON = 'bg-card text-foreground shadow-soft ring-1 ring-border/60';
export const SEG_OFF = 'text-muted-foreground hover:text-foreground';

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
