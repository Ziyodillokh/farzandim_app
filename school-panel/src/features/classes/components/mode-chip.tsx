'use client';

import { BookOpen, Coffee, Lock, Moon, PowerOff, ShieldOff, Sunrise, TriangleAlert } from 'lucide-react';
import type { ComponentType } from 'react';

import { Badge, type BadgeProps } from '@/components/ui/badge';
import type { ClassModeState } from '@/data/mock/school-mode-state';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

type Kind = ClassModeState['kind'];
type Variant = NonNullable<BadgeProps['variant']>;

const VARIANT: Record<Kind, Variant> = {
  LESSON: 'default',
  BREAK: 'info',
  BEFORE: 'secondary',
  AFTER: 'secondary',
  DAY_OFF: 'secondary',
  EMERGENCY_OFF: 'destructive',
  DISABLED: 'outline',
};

export const MODE_ICON: Record<Kind, ComponentType<{ className?: string }>> = {
  LESSON: BookOpen,
  BREAK: Coffee,
  BEFORE: Sunrise,
  AFTER: Moon,
  DAY_OFF: Moon,
  EMERGENCY_OFF: TriangleAlert,
  DISABLED: PowerOff,
};

/** Holat matni: "3-dars · 10:30 gacha", "Tanaffus · 09:45 gacha" va h.k. */
export function useModeLabel(): (state: ClassModeState) => string {
  const { t } = useI18n();
  return (state) => {
    switch (state.kind) {
      case 'LESSON':
        return t('classes.mode.LESSON', { no: state.periodNo, end: state.endsAt });
      case 'BREAK':
        return t('classes.mode.BREAK', { end: state.endsAt });
      case 'BEFORE':
        return t('classes.mode.BEFORE', { start: state.startsAt });
      default:
        return t(`classes.mode.${state.kind}`);
    }
  };
}

/** Sinf kartochkasidagi School Mode belgisi ("hozir faol / tanaffus / tugagan"). */
export function ModeChip({ state, className }: { state: ClassModeState; className?: string }) {
  const label = useModeLabel();
  const Icon = MODE_ICON[state.kind];
  return (
    <Badge variant={VARIANT[state.kind]} className={cn('gap-1.5 whitespace-nowrap', className)}>
      {state.kind === 'LESSON' && state.restricted ? (
        <span className="relative flex h-1.5 w-1.5">
          <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-current opacity-60" />
          <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-current" />
        </span>
      ) : (
        <Icon className="h-3 w-3" />
      )}
      {label(state)}
    </Badge>
  );
}

export function RestrictionHint({ state }: { state: ClassModeState }) {
  const { t } = useI18n();
  return (
    <span className={cn('inline-flex items-center gap-1 text-xs', state.restricted ? 'text-primary' : 'text-muted-foreground')}>
      {state.restricted ? <Lock className="h-3.5 w-3.5" /> : <ShieldOff className="h-3.5 w-3.5" />}
      {t(state.restricted ? 'classes.mode.restricted' : 'classes.mode.open')}
    </span>
  );
}
