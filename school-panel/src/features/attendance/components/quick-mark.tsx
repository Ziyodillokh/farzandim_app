'use client';

import type { AttendanceStatus } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { QUICK_STATUSES, STATUS_TONE } from '../lib';

/** Tezkor belgilash: Keldi / Kechikdi / Kelmadi / Sababli (segmentli boshqaruv). */
export function QuickMark({
  current,
  disabled,
  onSelect,
}: {
  current: AttendanceStatus | null;
  disabled?: boolean;
  onSelect: (status: AttendanceStatus) => void;
}) {
  const { t } = useI18n();
  return (
    <div className="inline-flex rounded-xl bg-primary/[0.05] p-1 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]" role="group">
      {QUICK_STATUSES.map((status) => {
        const active = current === status;
        return (
          <button
            key={status}
            type="button"
            disabled={disabled}
            aria-pressed={active}
            onClick={() => !active && onSelect(status)}
            className={cn(
              'inline-flex h-7 items-center gap-1.5 rounded-lg px-2.5 text-xs font-semibold transition-all disabled:cursor-not-allowed disabled:opacity-50',
              active ? cn('bg-card shadow-soft ring-1 ring-border/60', STATUS_TONE[status].text) : 'text-muted-foreground hover:bg-card/70 hover:text-foreground',
            )}
          >
            {active && <span className={cn('h-1.5 w-1.5 rounded-full', STATUS_TONE[status].dot)} aria-hidden />}
            {t(`attendance.classPage.quick.${status}`)}
          </button>
        );
      })}
    </div>
  );
}
