import { FileQuestion, Headphones, Library, type LucideIcon, PenLine, Video } from 'lucide-react';

import type { AssignmentKind, LearningAssignment } from '@/data/contracts';
import { WRITTEN_MATERIAL_ID } from '@/data/schemas/learning';
import type { useI18n } from '@/i18n';

type T = ReturnType<typeof useI18n>['t'];

export const KIND_ICONS: Record<AssignmentKind, LucideIcon> = { AUDIOBOOK: Headphones, VIDEO: Video, TEST: FileQuestion, WRITTEN: PenLine, LESSON: Library };

export const KIND_TONES: Record<AssignmentKind, string> = {
  AUDIOBOOK: 'bg-chart-5/10 text-chart-5 ring-chart-5/20',
  VIDEO: 'bg-primary/10 text-primary ring-primary/15',
  TEST: 'bg-success/10 text-success ring-success/20',
  WRITTEN: 'bg-warning/10 text-warning ring-warning/25',
  LESSON: 'bg-info/10 text-info ring-info/20',
};

/** [6, 7, 8] → "6–8-sinflar"; [5] → "5-sinf". */
export function gradesLabel(t: T, grades: readonly number[]): string {
  if (grades.length === 0) return '—';
  const from = Math.min(...grades);
  const to = Math.max(...grades);
  return from === to ? t('learning.materials.gradeSingle', { grade: from }) : t('learning.materials.grades', { from, to });
}

type AssignmentLike = Pick<LearningAssignment, 'materialId' | 'title'> & { materialKind: AssignmentKind | null; materialTitle: string };

/** Yozma vazifa: tur (`WRITTEN`) yoki katalogdan tashqari maxsus `materialId` bo'yicha aniqlanadi. */
export function isWrittenAssignment(a: Pick<AssignmentLike, 'materialId' | 'materialKind'>): boolean {
  return a.materialKind === 'WRITTEN' || a.materialId === WRITTEN_MATERIAL_ID;
}

/** Ko'rsatiladigan nom: yozma vazifada o'z sarlavhasi, aks holda material nomi. */
export function assignmentTitle(a: AssignmentLike): string {
  return isWrittenAssignment(a) ? (a.title?.trim() || a.materialTitle) : a.materialTitle;
}

export function assignmentKind(a: Pick<AssignmentLike, 'materialId' | 'materialKind'>): AssignmentKind | null {
  return isWrittenAssignment(a) ? 'WRITTEN' : a.materialKind;
}
