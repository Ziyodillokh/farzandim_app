'use client';

import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** "Jonli" belgisi — pulsatsiyalanuvchi yashil nuqta. */
export function LiveDot({ className }: { className?: string }) {
  return (
    <span className={cn('relative flex h-2 w-2', className)} aria-hidden>
      <span className="absolute inline-flex h-full w-full animate-pulse-ring rounded-full bg-success" />
      <span className="relative inline-flex h-2 w-2 rounded-full bg-success" />
    </span>
  );
}

export function LiveIndicator({ className, label }: { className?: string; label?: string }) {
  const { t } = useI18n();
  return (
    <span
      title={t('attendance.liveHint')}
      className={cn(
        'inline-flex items-center gap-2 rounded-full border border-success/25 bg-success/10 px-2.5 py-1 text-xs font-semibold text-success',
        className,
      )}
    >
      <LiveDot />
      {label ?? t('attendance.live')}
    </span>
  );
}
