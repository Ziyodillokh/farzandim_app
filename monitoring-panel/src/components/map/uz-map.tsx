'use client';

import { useMemo, useRef, useState, type KeyboardEvent, type ReactNode } from 'react';

import { UZ_MAP_VIEWBOX, UZ_REGION_SHAPES } from '@/data/geo/uz-regions';
import { useI18n } from '@/i18n';
import { buildScale, scaleColor, type ScaleSpec } from '@/lib/color-scale';
import { regionName, type RegionId } from '@/data/reference/regions';
import { cn } from '@/lib/utils';

export type MapDatum = { id: string; value: number | null; delta?: number | null; rank?: number | null };

type Props = {
  data: MapDatum[];
  /** Respublika qiymati — diverging shkala markazi. */
  center: number | null;
  better: 'up' | 'down' | 'neutral';
  format: (v: number | null) => string;
  formatDelta?: (d: number | null | undefined) => string;
  selectedId?: string | null;
  /** Viloyat roli: o'z hududi ajratiladi, qolganlari xira. */
  focusId?: string | null;
  onSelect?: (id: RegionId) => void;
  labels?: 'name' | 'value' | 'none';
  tooltipExtra?: (id: RegionId) => ReactNode;
  className?: string;
  ariaLabel: string;
};

const TK_ID = 'UZ-TK';
const TK_MARKER_R = 9;

/**
 * O'zbekiston choropleth xaritasi (14 hudud). SVG, kutubxonasiz: hover — shisha
 * tooltip, bosish/Enter — tanlash. Toshkent shahri kichik bo'lgani uchun alohida
 * belgi (doira) bilan ham ko'rsatiladi.
 */
export function UzMap({ data, center, better, format, formatDelta, selectedId, focusId, onSelect, labels = 'name', tooltipExtra, className, ariaLabel }: Props) {
  const { locale, t } = useI18n();
  const wrapRef = useRef<HTMLDivElement>(null);
  const [hover, setHover] = useState<{ id: RegionId; x: number; y: number } | null>(null);
  const byId = useMemo(() => new Map(data.map((d) => [d.id, d])), [data]);
  const scale: ScaleSpec = useMemo(() => buildScale(data.map((d) => d.value), better, center), [data, better, center]);
  const [, , vbW, vbH] = UZ_MAP_VIEWBOX.split(' ').map(Number) as [number, number, number, number];
  const tk = UZ_REGION_SHAPES.find((r) => r.id === TK_ID);

  const place = (id: RegionId, clientX: number, clientY: number) => {
    const rect = wrapRef.current?.getBoundingClientRect();
    if (!rect) return;
    setHover({ id, x: clientX - rect.left, y: clientY - rect.top });
  };
  const placeAtShape = (id: RegionId) => {
    const shape = UZ_REGION_SHAPES.find((r) => r.id === id);
    const rect = wrapRef.current?.getBoundingClientRect();
    if (!shape || !rect) return;
    setHover({ id, x: (shape.label[0] / vbW) * rect.width, y: (shape.label[1] / vbH) * rect.height });
  };
  const onKey = (id: RegionId) => (e: KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      onSelect?.(id);
    }
  };

  const hovered = hover ? byId.get(hover.id) : undefined;
  const wrapW = wrapRef.current?.clientWidth ?? 0;

  return (
    <div ref={wrapRef} className={cn('relative w-full select-none', className)} onMouseLeave={() => setHover(null)}>
      <svg viewBox={UZ_MAP_VIEWBOX} className="h-auto w-full overflow-visible" role="group" aria-label={ariaLabel}>
        <defs>
          <filter id="uzmap-glow" x="-20%" y="-20%" width="140%" height="140%">
            <feDropShadow dx="0" dy="0" stdDeviation="6" floodColor="hsl(195 100% 60%)" floodOpacity="0.55" />
          </filter>
          <filter id="uzmap-shadow" x="-10%" y="-10%" width="120%" height="120%">
            <feDropShadow dx="0" dy="8" stdDeviation="10" floodColor="#000" floodOpacity="0.35" />
          </filter>
        </defs>
        <g filter="url(#uzmap-shadow)">
          {UZ_REGION_SHAPES.map((shape) => {
            const id = shape.id as RegionId;
            const d = byId.get(id);
            const active = selectedId === id || hover?.id === id;
            const dimmed = focusId && focusId !== id;
            const name = regionName(id, locale);
            return (
              <path
                key={id}
                d={shape.d}
                fillRule="evenodd"
                tabIndex={onSelect ? 0 : -1}
                role={onSelect ? 'button' : 'img'}
                aria-label={`${name}: ${format(d?.value ?? null)}`}
                aria-pressed={onSelect ? selectedId === id : undefined}
                onMouseMove={(e) => place(id, e.clientX, e.clientY)}
                onFocus={() => placeAtShape(id)}
                onBlur={() => setHover(null)}
                onClick={() => onSelect?.(id)}
                onKeyDown={onKey(id)}
                className={cn('uzmap-region outline-none', onSelect && 'cursor-pointer', dimmed && 'opacity-35')}
                style={{ fill: scaleColor(d?.value ?? null, scale) }}
                stroke={active ? 'white' : 'hsl(var(--background))'}
                strokeWidth={active ? 2.2 : 1.1}
                filter={active ? 'url(#uzmap-glow)' : undefined}
              />
            );
          })}
        </g>
        {tk && (
          <g
            className={cn(onSelect && 'cursor-pointer')}
            onMouseMove={(e) => place(TK_ID, e.clientX, e.clientY)}
            onClick={() => onSelect?.(TK_ID)}
            aria-hidden
          >
            <circle cx={tk.centroid[0]} cy={tk.centroid[1]} r={TK_MARKER_R + 4} fill="transparent" />
            <circle
              cx={tk.centroid[0]}
              cy={tk.centroid[1]}
              r={TK_MARKER_R}
              style={{ fill: scaleColor(byId.get(TK_ID)?.value ?? null, scale) }}
              stroke="white"
              strokeWidth={selectedId === TK_ID || hover?.id === TK_ID ? 2.6 : 1.6}
              className="uzmap-region"
            />
          </g>
        )}
        {labels !== 'none' && (
          <g className="pointer-events-none">
            {UZ_REGION_SHAPES.map((shape) => {
              const id = shape.id as RegionId;
              const isTk = id === TK_ID;
              const [lx, ly] = isTk ? [shape.centroid[0] - 16, shape.centroid[1] - 16] : shape.label;
              const d = byId.get(id);
              // Kichik hududlarda (Farg'ona vodiysi) yozuv kichikroq — bir-biriga tegmasin.
              const small = !isTk && shape.bbox[2] - shape.bbox[0] < 110;
              return (
                <g key={id} className={cn(focusId && focusId !== id && 'opacity-40')}>
                  <text x={lx} y={ly} textAnchor={isTk ? 'end' : 'middle'} className={cn('uzmap-label', small && 'uzmap-label-sm')}>
                    {regionName(id, locale, true)}
                  </text>
                  {labels === 'value' && (
                    <text x={lx} y={ly + (small ? 12 : 15)} textAnchor={isTk ? 'end' : 'middle'} className={cn('uzmap-value', small && 'uzmap-value-sm')}>
                      {format(d?.value ?? null)}
                    </text>
                  )}
                </g>
              );
            })}
          </g>
        )}
      </svg>
      {hover && hovered !== undefined && (
        <div
          className="glass-popover pointer-events-none absolute z-20 min-w-[180px] rounded-xl px-3 py-2.5 text-xs shadow-glass-lg"
          style={{
            left: Math.min(Math.max(hover.x + 14, 4), Math.max(4, wrapW - 220)),
            top: Math.max(hover.y - 12, 4),
          }}
          role="status"
        >
          <p className="font-semibold text-foreground">{regionName(hover.id, locale)}</p>
          <p className="mt-1 flex items-baseline gap-2">
            <span className="font-display text-lg font-semibold tabular-nums text-foreground">{format(hovered.value)}</span>
            {formatDelta && hovered.delta !== undefined && <span className="text-muted-foreground tabular-nums">{formatDelta(hovered.delta)}</span>}
          </p>
          {hovered.rank ? <p className="mt-0.5 text-muted-foreground">{t('common.rankOf', { rank: hovered.rank, total: data.length })}</p> : null}
          {tooltipExtra?.(hover.id)}
        </div>
      )}
    </div>
  );
}

/** Xarita legendasi: 5 rang va izoh. */
export function MapLegend({ better, centerLabel, className }: { better: 'up' | 'down' | 'neutral'; centerLabel?: string; className?: string }) {
  const { t } = useI18n();
  const diverging = better !== 'neutral';
  const colors = diverging
    ? ['hsl(32 94% 54%)', 'hsl(40 88% 62%)', 'hsl(218 30% 52%)', 'hsl(199 88% 55%)', 'hsl(184 92% 47%)']
    : ['hsl(222 40% 34%)', 'hsl(219 55% 44%)', 'hsl(214 72% 52%)', 'hsl(204 86% 56%)', 'hsl(190 92% 52%)'];
  return (
    <div className={cn('flex flex-wrap items-center gap-x-2 gap-y-1.5 text-[0.7rem] text-muted-foreground', className)}>
      <span>{diverging ? t('map.legendWorse') : t('map.legendLow')}</span>
      <span className="flex overflow-hidden rounded-full ring-1 ring-inset ring-white/10">
        {colors.map((c) => (
          <span key={c} className="h-2.5 w-7" style={{ background: c }} />
        ))}
      </span>
      <span>{diverging ? t('map.legendBetter') : t('map.legendHigh')}</span>
      {centerLabel && <span className="ml-1 whitespace-nowrap rounded-full bg-muted px-2 py-0.5">● {centerLabel}</span>}
      <span className="hidden whitespace-nowrap sm:inline">· {t('map.quantileNote')}</span>
    </div>
  );
}
