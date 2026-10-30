'use client';

import { useMemo, useRef, useState } from 'react';

import { DISTRICTS_WITHOUT_GEOMETRY } from '@/data/geo/uz-district-index';
import { UZ_DISTRICT_SHAPES } from '@/data/geo/uz-districts';
import type { RegionId } from '@/data/reference/regions';
import { useI18n } from '@/i18n';
import { buildScale, scaleColor } from '@/lib/color-scale';
import { cn } from '@/lib/utils';
import type { MapDatum } from './uz-map';

const PAD = 8;
/** Juda kichik shaharlar (masalan, 0,1 km²) uchun bosiladigan belgi radiusi. */
const MIN_MARKER_R = 3.2;

/** Hudud ichidagi tumanlar xaritasi (OCHA ROCCA 2020 chegaralari). */
export function DistrictMap({
  regionId,
  data,
  center,
  better,
  format,
  selectedId,
  onSelect,
  className,
  ariaLabel,
}: {
  regionId: RegionId;
  data: MapDatum[];
  center: number | null;
  better: 'up' | 'down' | 'neutral';
  format: (v: number | null) => string;
  selectedId?: string | null;
  onSelect?: (id: string) => void;
  className?: string;
  ariaLabel: string;
}) {
  const { t } = useI18n();
  const wrapRef = useRef<HTMLDivElement>(null);
  const [hover, setHover] = useState<{ id: string; x: number; y: number } | null>(null);
  const region = UZ_DISTRICT_SHAPES[regionId];
  const byId = useMemo(() => new Map(data.map((d) => [d.id, d])), [data]);
  const scale = useMemo(() => buildScale(data.map((d) => d.value), better, center), [data, better, center]);
  if (!region) return null;
  const [x0, y0, x1, y1] = region.bbox;
  const viewBox = `${x0 - PAD} ${y0 - PAD} ${x1 - x0 + PAD * 2} ${y1 - y0 + PAD * 2}`;
  const missing = DISTRICTS_WITHOUT_GEOMETRY[regionId] ?? [];
  const hovered = hover ? region.districts.find((d) => d.id === hover.id) : undefined;
  const wrapW = wrapRef.current?.clientWidth ?? 0;
  // Shtrix qalinligi viewBox masshtabiga mos (kichik hududlarda chiziqlar qalin ko'rinmasin).
  const stroke = Math.max(0.25, (x1 - x0) / 420);

  return (
    <div ref={wrapRef} className={cn('relative w-full', className)} onMouseLeave={() => setHover(null)}>
      <svg viewBox={viewBox} className="h-auto max-h-[520px] w-full" role="group" aria-label={ariaLabel}>
        {region.districts.map((ds) => {
          const d = byId.get(ds.id);
          const active = selectedId === ds.id || hover?.id === ds.id;
          return (
            <path
              key={ds.id}
              d={ds.d}
              fillRule="evenodd"
              tabIndex={onSelect ? 0 : -1}
              role={onSelect ? 'button' : 'img'}
              aria-label={`${ds.name}: ${format(d?.value ?? null)}`}
              onMouseMove={(e) => {
                const rect = wrapRef.current?.getBoundingClientRect();
                if (rect) setHover({ id: ds.id, x: e.clientX - rect.left, y: e.clientY - rect.top });
              }}
              onClick={() => onSelect?.(ds.id)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault();
                  onSelect?.(ds.id);
                }
              }}
              className={cn('uzmap-region outline-none', onSelect && 'cursor-pointer')}
              style={{ fill: scaleColor(d?.value ?? null, scale) }}
              stroke={active ? 'white' : 'hsl(var(--background))'}
              strokeWidth={active ? stroke * 2.4 : stroke}
            />
          );
        })}
        {region.districts.map((ds) => (
          <circle key={`${ds.id}-m`} cx={ds.centroid[0]} cy={ds.centroid[1]} r={MIN_MARKER_R * stroke * 2} className="pointer-events-none fill-white/50" />
        ))}
      </svg>
      {hover && hovered && (
        <div
          className="glass-popover pointer-events-none absolute z-20 min-w-[170px] rounded-xl px-3 py-2 text-xs shadow-glass-lg"
          style={{ left: Math.min(Math.max(hover.x + 14, 4), Math.max(4, wrapW - 200)), top: Math.max(hover.y - 12, 4) }}
          role="status"
        >
          <p className="font-semibold text-foreground">{hovered.name}</p>
          <p className="mt-0.5 font-display text-base font-semibold tabular-nums text-foreground">{format(byId.get(hovered.id)?.value ?? null)}</p>
        </div>
      )}
      {missing.length > 0 && <p className="mt-2 text-[0.7rem] text-muted-foreground">{t('map.districtsNoShape', { names: missing.join(', ') })}</p>}
    </div>
  );
}
