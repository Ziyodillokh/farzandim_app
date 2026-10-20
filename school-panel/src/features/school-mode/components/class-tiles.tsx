'use client';

import { LayoutGrid } from 'lucide-react';

import { EmptyState } from '@/components/common/empty-state';
import { Skeleton } from '@/components/ui/skeleton';
import type { DeviceModeStatus } from '@/data/contracts';
import type { ClassModeRow, DeviceCounts, ShiftNow } from '@/data/mock/services/school-mode';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { stateTone, TONE_TILE } from '../lib';
import { ModeStateBadge, useStateDetail } from './mode-state-badge';

const SEGMENTS: ReadonlyArray<[DeviceModeStatus, string]> = [
  ['APPLIED', 'bg-success'],
  ['NO_PERMISSION', 'bg-warning'],
  ['OFFLINE', 'bg-destructive'],
  ['NO_PHONE', 'bg-muted-foreground/30'],
];
const GOOD_RATE = 90;
const FAIR_RATE = 75;
const GRID = 'grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6';

const rateClass = (rate: number) => (rate >= GOOD_RATE ? 'text-success' : rate >= FAIR_RATE ? 'text-foreground' : 'text-warning');

/** Qurilmalar qamrovi — holatlar bo'yicha qatlamli chiziq. */
export function ComplianceBar({ devices, className }: { devices: DeviceCounts; className?: string }) {
  const { t } = useI18n();
  const label = SEGMENTS.map(([k]) => `${t(`enums.deviceModeStatus.${k}`)}: ${devices[k]}`).join(' · ');
  return (
    <div className={cn('flex h-1.5 w-full gap-px overflow-hidden rounded-full bg-muted dark:bg-white/[0.06]', className)} role="img" aria-label={label} title={label}>
      {SEGMENTS.map(([k, color]) =>
        devices[k] > 0 ? <div key={k} className={cn('h-full transition-all duration-500', color)} style={{ width: `${(devices[k] / Math.max(1, devices.total)) * 100}%` }} /> : null,
      )}
    </div>
  );
}

export function ComplianceLegend() {
  const { t } = useI18n();
  return (
    <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
      {SEGMENTS.map(([k, color]) => (
        <span key={k} className="inline-flex items-center gap-1.5">
          <span className={cn('h-2 w-2 rounded-full', color)} aria-hidden />
          {t(`enums.deviceModeStatus.${k}`)}
        </span>
      ))}
    </div>
  );
}

function ClassTile({ row, selected, onSelect }: { row: ClassModeRow; selected: boolean; onSelect: (id: string) => void }) {
  const { t, tc } = useI18n();
  const detail = useStateDetail()(row.state);
  const tone = stateTone(row.state.kind);
  return (
    <button
      type="button"
      onClick={() => onSelect(row.classId)}
      aria-pressed={selected}
      className={cn(
        'card-glow flex flex-col rounded-xl p-3.5 text-left ring-1 ring-inset focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
        TONE_TILE[tone],
        selected && 'ring-2 ring-primary/70',
      )}
    >
      <div className="flex items-baseline justify-between gap-2">
        <span className="font-display text-lg font-semibold tracking-tight">{row.className}</span>
        <span className={cn('font-display text-sm font-semibold tabular-nums', rateClass(row.appliedRate))} title={t('schoolMode.classes.coverage')}>
          {row.appliedRate}%
        </span>
      </div>
      <div className="mt-2 flex min-h-[1.375rem] flex-wrap items-center gap-x-2 gap-y-1">
        <ModeStateBadge state={row.state} />
        {detail && <span className="text-2xs tabular-nums text-muted-foreground">{detail}</span>}
      </div>
      <ComplianceBar devices={row.devices} className="mt-3" />
      <div className="mt-2 flex min-h-4 items-center justify-between gap-2 text-2xs text-muted-foreground">
        <span>{tc('common.devicesCount', row.devices.total - row.devices.NO_PHONE)}</span>
        {row.activeExceptions > 0 && <span className="font-semibold text-info">{t('schoolMode.classes.exceptions', { count: row.activeExceptions })}</span>}
      </div>
    </button>
  );
}

/** Smena bo'limi sarlavhasi: nomi, hozirgi bosqich va sinflar soni. */
function ShiftHeading({ shift, count }: { shift: ShiftNow | undefined; count: number }) {
  const { t, tc } = useI18n();
  const p = shift?.phase;
  const phase = p
    ? t(`schoolMode.schedule.phase.${p.kind}`, { no: 'periodNo' in p ? p.periodNo : '', time: 'endsAt' in p ? p.endsAt : 'startsAt' in p ? p.startsAt : '' })
    : null;
  const live = p?.kind === 'LESSON' || p?.kind === 'BREAK';
  return (
    <div className="mb-3 flex items-center gap-3">
      <span className="font-display text-sm font-semibold">{shift?.name ?? '—'}</span>
      {phase && (
        <span className={cn('inline-flex items-center gap-1.5 text-xs', live ? 'font-medium text-primary' : 'text-muted-foreground')}>
          {live && <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-current" aria-hidden />}
          {phase}
        </span>
      )}
      <span className="h-px flex-1 bg-border/70" aria-hidden />
      <span className="text-xs text-muted-foreground">{tc('common.classesCount', count)}</span>
    </div>
  );
}

/** Sinf kartochkalari smenalar bo'yicha guruhlangan (hozirgi smena birinchi). Bosilsa — qurilmalar shu sinfga filtrlanadi. */
export function ClassTiles({
  rows,
  shifts,
  loading,
  selectedId,
  onSelect,
}: {
  rows: ClassModeRow[] | undefined;
  shifts: ShiftNow[];
  loading: boolean;
  selectedId: string | undefined;
  onSelect: (id: string) => void;
}) {
  const { t } = useI18n();
  if (loading && !rows) {
    return (
      <div className={GRID}>
        {Array.from({ length: 10 }).map((_, i) => (
          <Skeleton key={i} className="h-32 rounded-xl" />
        ))}
      </div>
    );
  }
  if (!rows || rows.length === 0) return <EmptyState icon={<LayoutGrid />} title={t('common.noData')} />;
  const groups = rows.reduce<Array<{ shiftId: string; items: ClassModeRow[] }>>((acc, row) => {
    const group = acc.find((g) => g.shiftId === row.shiftId);
    return group ? acc.map((g) => (g === group ? { ...g, items: [...g.items, row] } : g)) : [...acc, { shiftId: row.shiftId, items: [row] }];
  }, []);
  return (
    <div className="space-y-6">
      {groups.map((g) => (
        <section key={g.shiftId} aria-label={shifts.find((s) => s.id === g.shiftId)?.name}>
          <ShiftHeading shift={shifts.find((s) => s.id === g.shiftId)} count={g.items.length} />
          <div className={GRID}>
            {g.items.map((row) => (
              <ClassTile key={row.classId} row={row} selected={row.classId === selectedId} onSelect={onSelect} />
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
