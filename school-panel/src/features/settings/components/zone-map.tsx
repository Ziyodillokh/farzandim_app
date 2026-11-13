'use client';

import 'leaflet/dist/leaflet.css';

import type { Circle, CircleMarker, Map as LeafletMap } from 'leaflet';
import { useEffect, useRef } from 'react';

/**
 * Xarita plitkalari — OpenStreetMap (kalitsiz; panelda hududni belgilash kam so'rov, OSM tile policy doirasida).
 * CARTO basemaps endi kalitsiz so'rovga «API KEY REQUIRED» plitkasini qaytaradi.
 */
const TILE_URL = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const TILE_ATTRIBUTION = '© OpenStreetMap contributors';
const ZONE_COLOR = '#2563eb';
const START_ZOOM = 16;

type Props = {
  latitude: number;
  longitude: number;
  radiusM: number;
  /** Xarita bosilganda — yangi markaz (o'qish rejimida `undefined`). */
  onPick?: (latitude: number, longitude: number) => void;
  label: string;
};

/**
 * Maktab hududi xaritasi: markaz nuqtasi va radius doirasi. Leaflet faqat brauzerda (statik eksportda SSR yo'q)
 * dinamik yuklanadi; standart marker rasmi o'rniga `circleMarker` (bundler rasm yo'llari muammosiz).
 */
export function ZoneMap({ latitude, longitude, radiusM, onPick, label }: Props) {
  const container = useRef<HTMLDivElement>(null);
  const map = useRef<LeafletMap | null>(null);
  const center = useRef<CircleMarker | null>(null);
  const circle = useRef<Circle | null>(null);
  const pick = useRef(onPick);
  pick.current = onPick;

  useEffect(() => {
    let disposed = false;
    void import('leaflet').then((L) => {
      if (disposed || !container.current || map.current) return;
      const m = L.map(container.current, {
        zoomControl: true,
        attributionControl: true,
      }).setView([latitude, longitude], START_ZOOM);
      L.tileLayer(TILE_URL, { attribution: TILE_ATTRIBUTION, maxZoom: 19 }).addTo(m);
      circle.current = L.circle([latitude, longitude], {
        radius: radiusM,
        color: ZONE_COLOR,
        weight: 2,
        fillOpacity: 0.12,
      }).addTo(m);
      center.current = L.circleMarker([latitude, longitude], {
        radius: 7,
        color: '#ffffff',
        weight: 2,
        fillColor: ZONE_COLOR,
        fillOpacity: 1,
      }).addTo(m);
      m.on('click', (e) => pick.current?.(e.latlng.lat, e.latlng.lng));
      map.current = m;
    });
    return () => {
      disposed = true;
      map.current?.remove();
      map.current = null;
    };
    // Xarita bir marta quriladi; keyingi o'zgarishlar pastdagi effekt bilan.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const m = map.current;
    if (!m) return;
    center.current?.setLatLng([latitude, longitude]);
    circle.current?.setLatLng([latitude, longitude]).setRadius(radiusM);
    if (!m.getBounds().contains([latitude, longitude])) m.panTo([latitude, longitude]);
  }, [latitude, longitude, radiusM]);

  return (
    <div
      ref={container}
      role="application"
      aria-label={label}
      className="h-72 w-full overflow-hidden rounded-xl ring-1 ring-inset ring-border/60 [&_.leaflet-control-attribution]:text-[10px]"
    />
  );
}
