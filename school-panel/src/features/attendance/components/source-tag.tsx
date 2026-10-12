'use client';

import { Cpu, Hand, QrCode, ScanLine, type LucideIcon } from 'lucide-react';

import type { AttendanceSource } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const ICONS: Record<AttendanceSource, LucideIcon> = { QR: QrCode, KIOSK: ScanLine, MANUAL: Hand, SYSTEM: Cpu };

/** Qayd manbai: QR / kirish nuqtasi / qo'lda / tizim. */
export function SourceTag({ source, className }: { source: AttendanceSource; className?: string }) {
  const { t } = useI18n();
  const Icon = ICONS[source];
  return (
    <span className={cn('inline-flex items-center gap-1.5 text-xs text-muted-foreground', className)}>
      <Icon className="h-3.5 w-3.5 shrink-0" />
      {t(`enums.attendanceSource.${source}`)}
    </span>
  );
}
