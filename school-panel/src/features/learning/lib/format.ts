import { FileQuestion, Headphones, type LucideIcon, PenLine, Video } from 'lucide-react';

import type { AssignmentKind } from '@/data/contracts';
import type { useI18n } from '@/i18n';

type T = ReturnType<typeof useI18n>['t'];

export const KIND_ICONS: Record<AssignmentKind, LucideIcon> = { AUDIOBOOK: Headphones, VIDEO: Video, TEST: FileQuestion, WRITTEN: PenLine };

export const KIND_TONES: Record<AssignmentKind, string> = {
  AUDIOBOOK: 'bg-chart-5/10 text-chart-5 ring-chart-5/20',
  VIDEO: 'bg-primary/10 text-primary ring-primary/15',
  TEST: 'bg-success/10 text-success ring-success/20',
  WRITTEN: 'bg-warning/10 text-warning ring-warning/25',
};

/** [6, 7, 8] → "6–8-sinflar"; [5] → "5-sinf". */
export function gradesLabel(t: T, grades: readonly number[]): string {
  if (grades.length === 0) return '—';
  const from = Math.min(...grades);
  const to = Math.max(...grades);
  return from === to ? t('learning.materials.gradeSingle', { grade: from }) : t('learning.materials.grades', { from, to });
}
