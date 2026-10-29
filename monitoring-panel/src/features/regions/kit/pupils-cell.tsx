'use client';

import { useMetricFormat } from '@/lib/format';

/** "Monitoringda / rasmiy" o'quvchilar — ikki qatorda (sarlavha tartibida), ustun tor bo'lsin. */
export function PupilsCell({ covered, official }: { covered: number; official: number }) {
  const fmt = useMetricFormat();
  return (
    <span className="block whitespace-nowrap text-right leading-tight tabular-nums">
      <span className="block font-semibold">{fmt.count(covered)}</span>
      <span className="block text-[0.7rem] font-normal text-muted-foreground">/ {fmt.count(official)}</span>
    </span>
  );
}
