'use client';

import { Badge, type BadgeProps } from '@/components/ui/badge';
import type { ClassModeState } from '@/data/mock/services/school-mode';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { stateTone } from '../lib';

const VARIANT: Record<ReturnType<typeof stateTone>, NonNullable<BadgeProps['variant']>> = {
  primary: 'default',
  info: 'info',
  destructive: 'destructive',
  muted: 'secondary',
  success: 'success',
  warning: 'warning',
};

/** Sinfning School Mode holati: "3-dars", "Tanaffus", "Favqulodda o'chirilgan"… */
export function ModeStateBadge({ state, className }: { state: ClassModeState; className?: string }) {
  const { t } = useI18n();
  const tone = stateTone(state.kind);
  const label = state.kind === 'LESSON' ? t('schoolMode.state.LESSON', { no: state.periodNo }) : t(`schoolMode.state.${state.kind}`);
  return (
    <Badge variant={VARIANT[tone]} className={cn('whitespace-nowrap', className)}>
      <span className={cn('h-1.5 w-1.5 rounded-full bg-current', state.restricted && 'animate-pulse')} aria-hidden />
      {label}
    </Badge>
  );
}

/** Holatning qisqa izohi: "10:30 gacha", "13:30 da boshlanadi". */
export function useStateDetail(): (state: ClassModeState) => string | null {
  const { t } = useI18n();
  return (state) => {
    if (state.kind === 'LESSON' || state.kind === 'BREAK') return t('schoolMode.state.until', { time: state.endsAt });
    if (state.kind === 'BEFORE') return t('schoolMode.state.startsAt', { time: state.startsAt });
    return null;
  };
}
