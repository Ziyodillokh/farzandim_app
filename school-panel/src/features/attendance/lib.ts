'use client';

import type { AttendanceStatus, IsoDate } from '@/data/contracts';
import { toIsoDate } from '@/data/mock/calendar';
import type { DayCounts } from '@/data/mock/services/attendance';
import { useClockNow } from '@/features/engine/use-clock';
import type { TKey } from '@/i18n';

export { addDays, fromIsoDate } from '@/data/mock/calendar';

/** Qo'lda belgilash tugmalari tartibi. */
export const QUICK_STATUSES = ['PRESENT', 'LATE', 'ABSENT', 'EXCUSED'] as const satisfies readonly AttendanceStatus[];
export const ALL_STATUSES: readonly AttendanceStatus[] = ['PRESENT', 'LATE', 'ABSENT', 'LEFT_EARLY', 'EXCUSED'];

export type StatusKey = AttendanceStatus | 'PENDING';

type Tone = { bar: string; cell: string; dot: string; text: string; soft: string };

/** Holat ranglari: keldi — success, kechikdi — warning, kelmadi — destructive, erta ketdi — info, sababli — muted. */
export const STATUS_TONE: Record<StatusKey, Tone> = {
  PRESENT: { bar: 'bg-success', cell: 'bg-success/15 text-success', dot: 'bg-success', text: 'text-success', soft: 'bg-success/10' },
  LATE: { bar: 'bg-warning', cell: 'bg-warning/20 text-warning', dot: 'bg-warning', text: 'text-warning', soft: 'bg-warning/10' },
  ABSENT: { bar: 'bg-destructive', cell: 'bg-destructive/15 text-destructive', dot: 'bg-destructive', text: 'text-destructive', soft: 'bg-destructive/10' },
  LEFT_EARLY: { bar: 'bg-info', cell: 'bg-info/15 text-info', dot: 'bg-info', text: 'text-info', soft: 'bg-info/10' },
  EXCUSED: {
    bar: 'bg-muted-foreground/45',
    cell: 'bg-muted text-muted-foreground',
    dot: 'bg-muted-foreground/60',
    text: 'text-muted-foreground',
    soft: 'bg-muted',
  },
  PENDING: { bar: 'bg-border', cell: 'text-muted-foreground/60', dot: 'bg-border', text: 'text-muted-foreground', soft: 'bg-muted/60' },
};

/** `DayCounts` maydonlari ↔ holatlar (taxta, KPI, legenda). */
export const COUNT_FIELDS: ReadonlyArray<{ field: keyof Omit<DayCounts, 'total'>; status: StatusKey; labelKey: TKey }> = [
  { field: 'present', status: 'PRESENT', labelKey: 'attendance.stats.present' },
  { field: 'late', status: 'LATE', labelKey: 'attendance.stats.late' },
  { field: 'leftEarly', status: 'LEFT_EARLY', labelKey: 'attendance.stats.leftEarly' },
  { field: 'excused', status: 'EXCUSED', labelKey: 'attendance.stats.excused' },
  { field: 'absent', status: 'ABSENT', labelKey: 'attendance.stats.absent' },
  { field: 'pending', status: 'PENDING', labelKey: 'attendance.stats.pending' },
];

export const EMPTY_COUNTS: DayCounts = { present: 0, late: 0, absent: 0, leftEarly: 0, excused: 0, pending: 0, total: 0 };

export function sumCounts(list: readonly DayCounts[]): DayCounts {
  return list.reduce<DayCounts>(
    (acc, c) => ({
      present: acc.present + c.present,
      late: acc.late + c.late,
      absent: acc.absent + c.absent,
      leftEarly: acc.leftEarly + c.leftEarly,
      excused: acc.excused + c.excused,
      pending: acc.pending + c.pending,
      total: acc.total + c.total,
    }),
    EMPTY_COUNTS,
  );
}

/** Belgilanganlar orasida kelganlar ulushi (servisdagi `attendedRate` bilan bir xil). */
export function rateOf(c: DayCounts): number {
  const decided = c.total - c.pending;
  return decided > 0 ? Math.round(((c.present + c.late + c.leftEarly) / decided) * 100) : 0;
}

export function rateTextClass(rate: number): string {
  if (rate >= 90) return 'text-success';
  if (rate >= 75) return 'text-warning';
  return 'text-destructive';
}

/** Demo soati bo'yicha bugungi sana (SCENARIO rejimida — ssenariy kuni). */
export function useClockToday(): IsoDate {
  return toIsoDate(useClockNow(15_000));
}

/** URL'dagi `?date=` ni tekshirish: noto'g'ri yoki kelajak bo'lsa — undefined (bugun). */
export function parseDateParam(value: string | null, today: IsoDate): IsoDate | undefined {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value) || value >= today) return undefined;
  return value;
}
