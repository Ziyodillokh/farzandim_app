import { hashString } from '@/lib/rng';
import type { useI18n } from '@/i18n';
import { TIMETABLE_SUBJECT_KEYS } from '@/data/schemas/timetable';
import { isKnownSubject } from './grid';

type T = ReturnType<typeof useI18n>['t'];

/** Ma'lum fan kaliti → tarjima; erkin matn o'zi ko'rsatiladi. */
export function subjectLabel(t: T, subject: string): string {
  return isKnownSubject(subject) ? t(`timetable.subjects.${subject}`) : subject;
}

/** Katak foni: fan bo'yicha barqaror rang (to'liq klass satrlari — Tailwind skaneri uchun). */
const TINTS = [
  'bg-primary/[0.08] ring-primary/25',
  'bg-info/[0.09] ring-info/25',
  'bg-success/[0.08] ring-success/25',
  'bg-warning/[0.10] ring-warning/30',
  'bg-chart-5/10 ring-chart-5/25',
  'bg-sky-500/10 ring-sky-500/25',
] as const;

export function subjectTint(subject: string): string {
  const known = (TIMETABLE_SUBJECT_KEYS as readonly string[]).indexOf(subject);
  const index = known >= 0 ? known : hashString(subject.trim().toLowerCase());
  return TINTS[index % TINTS.length] ?? TINTS[0];
}
