'use client';

import { Building2, PlugZap, School, Users } from 'lucide-react';
import type { ReactNode } from 'react';

import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import type { Counts } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';

type Tile = { key: string; icon: ReactNode; label: string; value: string; hint: string; meter?: number };

const share = (part: number, total: number) => (total > 0 ? (part / total) * 100 : 0);

/** Dashboard KPI kartasi uslubida: nom, katta raqam, ixtiyoriy ulush chizig'i va izoh. */
function StatTile({ tile }: { tile: Tile }) {
  return (
    <Card className="relative h-full overflow-hidden p-4">
      <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_100%_0%,hsl(var(--primary)/0.12),transparent_60%)]" />
      <div className="relative flex items-start justify-between gap-2">
        <p className="text-[0.8rem] font-medium leading-snug text-muted-foreground">{tile.label}</p>
        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-inset ring-primary/20 [&_svg]:size-4">
          {tile.icon}
        </span>
      </div>
      <p className="relative mt-1 font-display text-[1.3rem] font-semibold leading-tight tracking-[-0.02em] sm:text-[1.6rem]">{tile.value}</p>
      {tile.meter !== undefined && (
        <div aria-hidden className="relative mt-2.5 h-1.5 overflow-hidden rounded-full bg-primary/15">
          <span className="block h-full rounded-full bg-brand-gradient" style={{ width: `${Math.min(100, Math.max(0, tile.meter))}%` }} />
        </div>
      )}
      <p className="relative mt-2 text-[0.72rem] leading-snug text-muted-foreground">{tile.hint}</p>
    </Card>
  );
}

/** Maktablar sahifasi boshidagi 4 ta raqam: maktablar, ulanganlar, xususiylar, monitoringdagi o'quvchilar. */
export function SchoolKpis({ counts }: { counts: Counts | undefined }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  if (!counts) {
    return (
      <div className="grid grid-cols-2 gap-3 xl:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-[138px] rounded-2xl" />
        ))}
      </div>
    );
  }
  const connected = share(counts.schoolsConnected, counts.schools);
  const covered = share(counts.covered, counts.official);
  const tiles: Tile[] = [
    { key: 'schools', icon: <School />, label: t('schools.kpi.schools'), value: fmt.count(counts.schools), hint: t('schools.kpi.schoolsHint') },
    {
      key: 'connected',
      icon: <PlugZap />,
      label: t('schools.kpi.connected'),
      value: fmt.count(counts.schoolsConnected),
      hint: t('schools.kpi.connectedHint', { share: fmt.pct(connected) }),
      meter: connected,
    },
    {
      key: 'private',
      icon: <Building2 />,
      label: t('schools.kpi.private'),
      value: fmt.count(counts.privateSchools),
      hint: t('schools.kpi.privateHint', { share: fmt.pct(share(counts.privateSchools, counts.schools)) }),
    },
    {
      key: 'pupils',
      icon: <Users />,
      label: t('schools.kpi.pupils'),
      value: fmt.count(counts.covered),
      hint: t('schools.kpi.pupilsHint', { official: fmt.count(counts.official) }),
      meter: covered,
    },
  ];
  return (
    <div className="grid grid-cols-2 gap-3 xl:grid-cols-4">
      {tiles.map((tile) => (
        <StatTile key={tile.key} tile={tile} />
      ))}
    </div>
  );
}
