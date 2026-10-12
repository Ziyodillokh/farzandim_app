import { FileQuestion, Headphones, type LucideIcon, Video } from 'lucide-react';

import type { MaterialKind } from '@/data/contracts';
import type { useI18n } from '@/i18n';

type T = ReturnType<typeof useI18n>['t'];

export const KIND_ICONS: Record<MaterialKind, LucideIcon> = { AUDIOBOOK: Headphones, VIDEO: Video, TEST: FileQuestion };

export const KIND_TONES: Record<MaterialKind, string> = {
  AUDIOBOOK: 'bg-chart-5/10 text-chart-5',
  VIDEO: 'bg-primary/10 text-primary',
  TEST: 'bg-success/10 text-success',
};

/** [6, 7, 8] → "6–8-sinflar"; [5] → "5-sinf". */
export function gradesLabel(t: T, grades: readonly number[]): string {
  if (grades.length === 0) return '—';
  const from = Math.min(...grades);
  const to = Math.max(...grades);
  return from === to ? t('learning.materials.gradeSingle', { grade: from }) : t('learning.materials.grades', { from, to });
}
