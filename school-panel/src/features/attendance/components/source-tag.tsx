'use client';

import { Cpu, Hand, QrCode, ScanLine, type LucideIcon } from 'lucide-react';

import type { AttendanceSource } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const ICONS: Record<AttendanceSource, LucideIcon> = { QR: QrCode, KIOSK: ScanLine, MANUAL: Hand, SYSTEM: Cpu };

/** Qayd manbai: QR / kirish nuqtasi / qo'lda / tizim. `pill` — jadvallarda yumshoq kapsula. */
export function SourceTag({ source, className, variant = 'pill' }: { source: AttendanceSource; className?: string; variant?: 'pill' | 'plain' }) {
  const { t } = useI18n();
  const Icon = ICONS[source];
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 whitespace-nowrap text-xs text-muted-foreground',
        variant === 'pill' && 'rounded-full bg-white/50 px-2 py-0.5 ring-1 ring-inset ring-border/60 dark:bg-white/[0.03]',
        className,
      )}
    >
      <Icon className="h-3.5 w-3.5 shrink-0 text-primary/70" />
      {t(`enums.attendanceSource.${source}`)}
    </span>
  );
}
