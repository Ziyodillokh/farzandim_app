'use client';

import { LayoutGrid } from 'lucide-react';

import { EmptyState } from '@/components/common/empty-state';
import { Skeleton } from '@/components/ui/skeleton';
import type { DeviceModeStatus } from '@/data/contracts';
import type { ClassModeRow, DeviceCounts } from '@/data/mock/services/school-mode';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { stateTone, TONE_RING } from '../lib';
import { ModeStateBadge, useStateDetail } from './mode-state-badge';

const SEGMENTS: ReadonlyArray<[DeviceModeStatus, string]> = [
  ['APPLIED', 'bg-success'],
  ['NO_PERMISSION', 'bg-warning'],
  ['OFFLINE', 'bg-destructive'],
  ['NO_PHONE', 'bg-muted-foreground/30'],
];

/** Qurilmalar qamrovi — holatlar bo'yicha qatlamli chiziq. */
export function ComplianceBar({ devices, className }: { devices: DeviceCounts; className?: string }) {
  const { t } = useI18n();
  const label = SEGMENTS.map(([k]) => `${t(`enums.deviceModeStatus.${k}`)}: ${devices[k]}`).join(' · ');
  return (
    <div className={cn('flex h-2 w-full overflow-hidden rounded-full bg-muted', className)} role="img" aria-label={label} title={label}>
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
        'card-glow flex flex-col rounded-xl border bg-card p-4 text-left shadow-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
        TONE_RING[tone],
        selected && 'ring-2 ring-primary ring-offset-2 ring-offset-background',
      )}
    >
      <div className="flex items-baseline justify-between gap-2">
        <span className="font-display text-xl font-semibold tracking-tight">{row.className}</span>
        <span className="text-2xs font-medium text-muted-foreground">{row.shiftName}</span>
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1">
        <ModeStateBadge state={row.state} />
        {detail && <span className="text-2xs text-muted-foreground">{detail}</span>}
      </div>
      <div className="mt-4 flex items-baseline justify-between text-xs">
        <span className="text-muted-foreground">{t('schoolMode.classes.coverage')}</span>
        <span className="font-semibold tabular-nums">{row.appliedRate}%</span>
      </div>
      <ComplianceBar devices={row.devices} className="mt-1.5" />
      <div className="mt-2 flex min-h-4 items-center justify-between gap-2 text-2xs text-muted-foreground">
        <span>{tc('common.devicesCount', row.devices.total - row.devices.NO_PHONE)}</span>
        {row.activeExceptions > 0 && <span className="font-semibold text-info">{t('schoolMode.classes.exceptions', { count: row.activeExceptions })}</span>}
      </div>
    </button>
  );
}

/** Sinf kartochkalari — bosilsa qurilmalar jadvali shu sinfga filtrlanadi. */
export function ClassTiles({
  rows,
  loading,
  selectedId,
  onSelect,
}: {
  rows: ClassModeRow[] | undefined;
  loading: boolean;
  selectedId: string | undefined;
  onSelect: (id: string) => void;
}) {
  const { t } = useI18n();
  if (loading && !rows) {
    return (
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton key={i} className="h-40 rounded-xl" />
        ))}
      </div>
    );
  }
  if (!rows || rows.length === 0) return <EmptyState icon={<LayoutGrid />} title={t('common.noData')} />;
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6">
      {rows.map((row) => (
        <ClassTile key={row.classId} row={row} selected={row.classId === selectedId} onSelect={onSelect} />
      ))}
    </div>
  );
}
