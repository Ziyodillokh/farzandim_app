'use client';

import { Crosshair, MapPin, ShieldCheck, Trash2 } from 'lucide-react';
import { useEffect, useState } from 'react';
import { toast } from 'sonner';

import { useCan } from '@/auth/use-session';
import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import type { School } from '@/data/contracts';
import { schoolZoneSchema, ZONE_RADIUS_DEFAULT_M, ZONE_RADIUS_MAX_M, ZONE_RADIUS_MIN_M } from '@/data/schemas/school';
import { useI18n } from '@/i18n';
import { formErrorKey } from '@/lib/errors';
import { cn } from '@/lib/utils';
import { useClearZone, useSetZone } from '../hooks';
import { TILE } from '../styles';
import { ZoneMap } from './zone-map';

/** Hudud belgilanmagan maktab uchun xarita boshlang'ich nuqtasi (Toshkent markazi). */
const FALLBACK_CENTER = { latitude: 41.311081, longitude: 69.240562 };
const COORD_DIGITS = 6;
const GEO_TIMEOUT_MS = 15_000;

const round = (v: number) => Number(v.toFixed(COORD_DIGITS));

/**
 * Maktab hududi (School Mode «faqat hududda»): xaritani bosib markazni tanlash, radius va koordinatalar.
 * Telefon hududda ekanini bolaning telefoni o'zi aniqlaydi — maktab hech kimning joylashuvini ko'rmaydi.
 */
export function ZoneCard({ school }: { school: School }) {
  const { t } = useI18n();
  const canManage = useCan()('settings.manage');
  const save = useSetZone();
  const clear = useClearZone();
  const hasZone = school.latitude != null && school.longitude != null && Boolean(school.zoneRadiusM);

  const [latitude, setLatitude] = useState(school.latitude ?? FALLBACK_CENTER.latitude);
  const [longitude, setLongitude] = useState(school.longitude ?? FALLBACK_CENTER.longitude);
  const [radius, setRadius] = useState(school.zoneRadiusM ?? ZONE_RADIUS_DEFAULT_M);
  const [locating, setLocating] = useState(false);

  // Saqlangandan / boshqa qurilmada o'zgargandan keyin — server qiymati.
  useEffect(() => {
    if (school.latitude != null) setLatitude(school.latitude);
    if (school.longitude != null) setLongitude(school.longitude);
    if (school.zoneRadiusM) setRadius(school.zoneRadiusM);
  }, [school.latitude, school.longitude, school.zoneRadiusM]);

  const parsed = schoolZoneSchema.safeParse({
    latitude,
    longitude,
    radiusM: radius,
  });
  const issue = parsed.success ? null : parsed.error.issues[0];
  const dirty = !hasZone || latitude !== school.latitude || longitude !== school.longitude || radius !== school.zoneRadiusM;

  const pick = (lat: number, lng: number) => {
    if (!canManage) return;
    setLatitude(round(lat));
    setLongitude(round(lng));
  };

  const locate = () => {
    if (!navigator.geolocation) return toast.error(t('settings.zone.locateFailed'));
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setLocating(false);
        pick(pos.coords.latitude, pos.coords.longitude);
      },
      () => {
        setLocating(false);
        toast.error(t('settings.zone.locateFailed'));
      },
      { enableHighAccuracy: true, timeout: GEO_TIMEOUT_MS },
    );
  };

  return (
    <div id="school-zone" className="scroll-mt-24">
      <SectionCard
        icon={<MapPin />}
        title={t('settings.zone.title')}
        description={t('settings.zone.description')}
        actions={
          <Badge variant={hasZone ? 'success' : 'outline'}>
            {hasZone ? t('settings.zone.set', { radius: school.zoneRadiusM ?? 0 }) : t('settings.zone.notSet')}
          </Badge>
        }
      >
        <ZoneMap latitude={latitude} longitude={longitude} radiusM={radius} onPick={canManage ? pick : undefined} label={t('settings.zone.mapLabel')} />
        {canManage && <p className="mt-2 text-xs text-muted-foreground">{t('settings.zone.mapHint')}</p>}

        <div className="mt-4 grid gap-3 sm:grid-cols-3">
          <label className="grid gap-1.5 text-sm">
            <span className="font-medium">{t('settings.zone.latitude')}</span>
            <Input inputMode="decimal" value={latitude} disabled={!canManage} onChange={(e) => setLatitude(Number(e.target.value))} />
          </label>
          <label className="grid gap-1.5 text-sm">
            <span className="font-medium">{t('settings.zone.longitude')}</span>
            <Input inputMode="decimal" value={longitude} disabled={!canManage} onChange={(e) => setLongitude(Number(e.target.value))} />
          </label>
          <label className="grid gap-1.5 text-sm">
            <span className="font-medium">{t('settings.zone.radius', { radius })}</span>
            <input
              type="range"
              min={ZONE_RADIUS_MIN_M}
              max={ZONE_RADIUS_MAX_M}
              step={10}
              value={radius}
              disabled={!canManage}
              onChange={(e) => setRadius(Number(e.target.value))}
              className="h-9 accent-primary"
              aria-label={t('settings.zone.radiusLabel')}
            />
          </label>
        </div>
        {issue && <p className="mt-2 text-sm text-destructive">{t(formErrorKey(String(issue.message)))}</p>}

        <div className={cn('mt-4 flex items-start gap-2.5 p-3 text-xs leading-relaxed text-muted-foreground', TILE)}>
          <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-success" aria-hidden />
          {t('settings.zone.privacy')}
        </div>

        {canManage && (
          <div className="mt-4 flex flex-wrap gap-2">
            <Button type="button" variant="outline" onClick={locate} loading={locating}>
              <Crosshair />
              {t('settings.zone.locate')}
            </Button>
            <Button type="button" disabled={!parsed.success || !dirty} loading={save.isPending} onClick={() => parsed.success && save.mutate(parsed.data)}>
              {t('common.save')}
            </Button>
            {hasZone && (
              <Button type="button" variant="ghost" className="text-destructive" loading={clear.isPending} onClick={() => clear.mutate()}>
                <Trash2 />
                {t('settings.zone.remove')}
              </Button>
            )}
          </div>
        )}
      </SectionCard>
    </div>
  );
}
