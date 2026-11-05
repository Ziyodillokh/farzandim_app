'use client';

import { Check, Clock3, type LucideIcon, Minus, Undo2 } from 'lucide-react';

import { Badge, type BadgeProps } from '@/components/ui/badge';
import type { SubmissionState } from '@/data/contracts';
import { useI18n } from '@/i18n';

const VISUAL: Record<SubmissionState, { variant: NonNullable<BadgeProps['variant']>; icon: LucideIcon }> = {
  NOT_SUBMITTED: { variant: 'secondary', icon: Minus },
  SUBMITTED: { variant: 'info', icon: Clock3 },
  ACCEPTED: { variant: 'success', icon: Check },
  RETURNED: { variant: 'warning', icon: Undo2 },
};

/** Holat belgisi: rang + ikonka + matn (faqat rangga tayanmaydi). */
export function SubmissionStatusChip({ state, size }: { state: SubmissionState; size?: BadgeProps['size'] }) {
  const { t } = useI18n();
  const { variant, icon: Icon } = VISUAL[state];
  return (
    <Badge variant={variant} size={size} className="whitespace-nowrap">
      <Icon className="h-3 w-3" aria-hidden />
      {t(`learning.submissions.states.${state}`)}
    </Badge>
  );
}
