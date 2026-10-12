'use client';

import type { AttendanceStatus } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { QUICK_STATUSES, STATUS_TONE } from '../lib';

/** Tezkor belgilash: Keldi / Kechikdi / Kelmadi / Sababli (segmentli tugmalar). */
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
    <div className="inline-flex rounded-lg border bg-muted/50 p-0.5" role="group">
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
              'h-7 rounded-md px-2.5 text-xs font-semibold transition-all disabled:cursor-not-allowed disabled:opacity-50',
              active
                ? cn('bg-card shadow-soft', STATUS_TONE[status].text)
                : 'text-muted-foreground hover:bg-card/70 hover:text-foreground',
            )}
          >
            {t(`attendance.classPage.quick.${status}`)}
          </button>
        );
      })}
    </div>
  );
}
