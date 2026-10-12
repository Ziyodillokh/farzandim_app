import type { DayCounts } from '@/data/mock/services/attendance';
import { cn } from '@/lib/utils';
import { COUNT_FIELDS, STATUS_TONE } from '../lib';

/** Holatlar ulushi — bitta gorizontal chiziq (kutilayotganlar — fon). */
export function StackedBar({ counts, className, label }: { counts: DayCounts; className?: string; label?: string }) {
  const total = counts.total || 1;
  return (
    <div className={cn('flex h-2 w-full overflow-hidden rounded-full bg-muted', className)} role="img" aria-label={label}>
      {COUNT_FIELDS.filter(({ field }) => field !== 'pending' && counts[field] > 0).map(({ field, status }) => (
        <div
          key={field}
          className={cn('h-full transition-[width] duration-700 ease-out', STATUS_TONE[status].bar)}
          style={{ width: `${(counts[field] / total) * 100}%` }}
        />
      ))}
    </div>
  );
}
