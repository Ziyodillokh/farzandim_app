import { BookOpen, HandHeart, type LucideIcon, MessageCircle, ShieldCheck, Smile, Users } from 'lucide-react';

import type { AgeGroup, CareAggregateGroup, CareTopic } from '@/data/contracts';
import type { CareBreakdown } from '@/data/schemas/care';
import type { useI18n } from '@/i18n';

type T = ReturnType<typeof useI18n>['t'];

export const TOPIC_ICONS: Record<CareTopic, LucideIcon> = {
  WELLBEING: Smile,
  LEARNING: BookOpen,
  PEERS: Users,
  SAFETY: ShieldCheck,
  SUPPORT: HandHeart,
  FEEDBACK: MessageCircle,
};

/** Guruh nomi — kesimga qarab tarjima qilinadi. */
export function groupLabel(t: T, breakdown: CareBreakdown, group: Pick<CareAggregateGroup, 'key' | 'label'>): string {
  switch (breakdown) {
    case 'SCHOOL':
      return t('care.breakdown.SCHOOL');
    case 'AGE_GROUP':
      return t(`enums.ageGroup.${group.key as AgeGroup}`);
    case 'GRADE':
      return t('care.gradeLabel', { grade: group.label });
    case 'CLASS':
      return group.label;
  }
}

export function ageGroupsLabel(t: T, groups: readonly AgeGroup[]): string {
  return groups.map((g) => t(`enums.ageGroup.${g}`)).join(', ');
}
