'use client';

import type { ReactNode } from 'react';
import { AlertTriangle, CheckCircle2, CircleOff, Library } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { KELAJAK_AGE_GROUPS } from '@/lib/constants/kelajak';
import { cn, formatCompact } from '@/lib/utils';
import type { KelajakStats } from '@/types/api.types';
import { CategoryBreakdown, TypesAndSessions } from './kelajak-stats-breakdown';

export function KelajakStatsCards({
  stats,
  isLoading,
  error,
}: {
  stats: KelajakStats | undefined;
  isLoading: boolean;
  /** `/stats` xatosi — kartalar "—" bo'lib qolmasin, sababi ko'rinsin. */
  error: string | null;
}) {
  return (
    <div className="mb-6 space-y-4">
      {error && (
        <p role="alert" className="rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-xs text-destructive">
          Statistikani yuklab bo&apos;lmadi: {error}
        </p>
      )}
      <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
        <StatTile
          icon={<Library />}
          label="Jami savollar"
          value={stats?.total}
          loading={isLoading}
          className="bg-primary/10 text-primary"
        />
        <StatTile
          icon={<CheckCircle2 />}
          label="Faol"
          value={stats?.active}
          loading={isLoading}
          className="bg-success/10 text-success"
        />
        <StatTile
          icon={<CircleOff />}
          label="Nofaol"
          value={stats?.inactive}
          loading={isLoading}
          className="bg-muted text-muted-foreground"
        />
        <StatTile
          icon={<AlertTriangle />}
          label="Ko'rib chiqish kerak"
          value={stats?.needsReview}
          loading={isLoading}
          className="bg-warning/10 text-warning"
        />
      </div>

      <Card className="p-4">
        <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          Yosh guruhlari bo&apos;yicha
        </p>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {KELAJAK_AGE_GROUPS.map((group) => {
            const row = stats?.byAgeGroup.find((g) => g.ageGroup === group.value);
            return (
              <div key={group.value} className="rounded-lg border border-border bg-muted/30 px-3 py-2.5">
                <p className="text-xs font-medium text-muted-foreground">{group.label}</p>
                {isLoading ? (
                  <Skeleton className="mt-1.5 h-6 w-16" />
                ) : (
                  <p className="mt-0.5 text-lg font-bold tabular-nums">
                    {row?.total ?? 0}
                    <span className="ml-1.5 text-xs font-medium text-muted-foreground">
                      faol: {row?.active ?? 0}
                    </span>
                  </p>
                )}
              </div>
            );
          })}
        </div>
      </Card>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <CategoryBreakdown stats={stats} isLoading={isLoading} />
        <TypesAndSessions stats={stats} isLoading={isLoading} />
      </div>
    </div>
  );
}

function StatTile({
  icon,
  label,
  value,
  loading,
  className,
}: {
  icon: ReactNode;
  label: string;
  value: number | undefined;
  loading: boolean;
  className: string;
}) {
  return (
    <Card className="p-4">
      <div className={cn('mb-3 flex h-10 w-10 items-center justify-center rounded-lg [&_svg]:size-5', className)}>
        {icon}
      </div>
      <p className="text-xs font-medium text-muted-foreground">{label}</p>
      {loading ? (
        <Skeleton className="mt-2 h-7 w-16" />
      ) : (
        <p className="mt-1 text-2xl font-bold tabular-nums">
          {value == null ? '—' : formatCompact(value)}
        </p>
      )}
    </Card>
  );
}
