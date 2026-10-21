'use client';

import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { answerTypeLabel, categoryLabel } from '@/lib/constants/kelajak';
import type { KelajakStats } from '@/types/api.types';

/** Kategoriya bo'yicha jami / faol (backend `byCategory`, katalog tartibida). */
export function CategoryBreakdown({ stats, isLoading }: { stats: KelajakStats | undefined; isLoading: boolean }) {
  return (
    <Card className="p-4">
      <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
        Kategoriyalar bo&apos;yicha
      </h3>
      {isLoading || !stats ? (
        <RowsSkeleton rows={6} />
      ) : (
        <table className="w-full text-sm">
          <thead className="sr-only">
            <tr>
              <th>Kategoriya</th>
              <th>Jami</th>
              <th>Faol</th>
            </tr>
          </thead>
          <tbody>
            {stats.byCategory.map((c) => (
              <tr key={c.category} className="border-b border-border/60 last:border-0">
                <td className="py-1.5 pr-3">{categoryLabel(c.category)}</td>
                <td className="py-1.5 text-right font-semibold tabular-nums">{c.total}</td>
                <td className="w-24 py-1.5 text-right text-xs text-muted-foreground tabular-nums">faol: {c.active}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Card>
  );
}

/** Javob turlari (nol bo'lganlari ko'rsatilmaydi) va sessiyalar. */
export function TypesAndSessions({ stats, isLoading }: { stats: KelajakStats | undefined; isLoading: boolean }) {
  const types = stats?.byAnswerType.filter((t) => t.total > 0) ?? [];
  return (
    <div className="space-y-4">
      <Card className="p-4">
        <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Javob turlari</h3>
        {isLoading || !stats ? (
          <RowsSkeleton rows={4} />
        ) : (
          <ul className="space-y-1.5 text-sm">
            {types.map((t) => (
              <li key={t.answerType} className="flex items-center justify-between gap-3">
                <span>{answerTypeLabel(t.answerType)}</span>
                <span className="tabular-nums">
                  <span className="font-semibold">{t.total}</span>
                  <span className="ml-2 text-xs text-muted-foreground">faol: {t.active}</span>
                </span>
              </li>
            ))}
          </ul>
        )}
      </Card>
      <Card className="p-4">
        <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">Sessiyalar</h3>
        {isLoading || !stats ? (
          <RowsSkeleton rows={3} />
        ) : (
          <dl className="grid grid-cols-3 gap-3 text-center">
            <Metric label="Jami" value={stats.sessions.total} />
            <Metric label="Yakunlangan" value={stats.sessions.completed} />
            <Metric label="Oxirgi 7 kun" value={stats.sessions.completedLast7Days} />
          </dl>
        )}
      </Card>
    </div>
  );
}

function Metric({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-lg border border-border bg-muted/30 px-2 py-2">
      <dt className="text-2xs font-medium uppercase tracking-wider text-muted-foreground">{label}</dt>
      <dd className="mt-0.5 text-lg font-bold tabular-nums">{value}</dd>
    </div>
  );
}

function RowsSkeleton({ rows }: { rows: number }) {
  return (
    <div className="space-y-2">
      {Array.from({ length: rows }).map((_, i) => (
        <Skeleton key={i} className="h-4 w-full" />
      ))}
    </div>
  );
}
