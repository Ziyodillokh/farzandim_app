'use client';

import { Check, Clock3, FileCheck2, X, type LucideIcon } from 'lucide-react';

import type { AttendanceStatus } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { QUICK_STATUSES, STATUS_TONE } from '../lib';

const ICONS: Record<(typeof QUICK_STATUSES)[number], LucideIcon> = {
  PRESENT: Check,
  LATE: Clock3,
  ABSENT: X,
  EXCUSED: FileCheck2,
};

/**
 * Tezkor belgilash: Keldi / Kechikdi / Kelmadi / Sababli (segmentli boshqaruv).
 * Telefonda (sm dan kichik) — 36px ikonka tugmalar, nomi `aria-label` va `title` da.
 */
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
    <div className="inline-flex rounded-xl bg-primary/[0.05] p-0.5 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03] sm:gap-0.5 sm:p-1" role="group">
      {QUICK_STATUSES.map((status) => {
        const active = current === status;
        const label = t(`attendance.classPage.quick.${status}`);
        const Icon = ICONS[status];
        return (
          <button
            key={status}
            type="button"
            disabled={disabled}
            aria-pressed={active}
            aria-label={label}
            title={label}
            onClick={() => !active && onSelect(status)}
            className={cn(
              'inline-flex h-9 w-9 items-center justify-center gap-1.5 rounded-lg text-xs font-semibold transition-all disabled:cursor-not-allowed disabled:opacity-50 sm:h-7 sm:w-auto sm:px-2.5',
              active ? cn('bg-card shadow-soft ring-1 ring-border/60', STATUS_TONE[status].text) : 'text-muted-foreground hover:bg-card/70 hover:text-foreground',
            )}
          >
            <Icon className="h-4 w-4 sm:hidden" aria-hidden />
            {active && <span className={cn('hidden h-1.5 w-1.5 rounded-full sm:inline-block', STATUS_TONE[status].dot)} aria-hidden />}
            <span className="hidden sm:inline">{label}</span>
          </button>
        );
      })}
    </div>
  );
}
