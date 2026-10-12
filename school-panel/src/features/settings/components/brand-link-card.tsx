'use client';

import { Copy, ExternalLink, Info, Link2, TriangleAlert } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';

import { SchoolLogo } from '@/components/common/school-logo';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import type { School } from '@/data/contracts';
import { useCopy } from '@/features/parents/hooks';
import { useI18n } from '@/i18n';
import { BASE_PATH } from '@/lib/base-path';
import { brandLink, decodeBrand } from '@/lib/brand-link';
import { cn } from '@/lib/utils';
import { TILE } from '../styles';

/** "Shu maktab uchun havola" — nom va logo URL fragmentida (serverga ketmaydi). */
export function BrandLinkCard({ school }: { school: School }) {
  const { t } = useI18n();
  const copy = useCopy();
  const [origin, setOrigin] = useState<string | null>(null);

  useEffect(() => {
    setOrigin(window.location.origin);
  }, []);

  const link = useMemo(
    () => (origin ? brandLink(origin, BASE_PATH, { name: school.name, shortName: school.shortName, city: school.city, logo: school.logo }) : ''),
    [origin, school.name, school.shortName, school.city, school.logo],
  );
  const logoOmitted = useMemo(() => {
    if (!link || !school.logo) return false;
    return decodeBrand(`#${link.split('#')[1] ?? ''}`)?.logo === null;
  }, [link, school.logo]);

  return (
    <SectionCard icon={<Link2 />} title={t('settings.brand.title')} description={t('settings.brand.description')}>
      <div className="grid gap-5 md:grid-cols-[1fr_220px]">
        <div className="min-w-0 space-y-3">
          {link ? (
            <div className="flex gap-2">
              <Input value={link} readOnly onFocus={(e) => e.currentTarget.select()} className="font-mono text-xs" aria-label={t('settings.brand.title')} />
              <Button variant="outline" size="icon" onClick={() => void copy(link, 'settings.brand.copied')} aria-label={t('settings.brand.copy')} title={t('settings.brand.copy')}>
                <Copy />
              </Button>
              <Button asChild variant="outline" size="icon" title={t('settings.brand.open')}>
                <a href={link} target="_blank" rel="noopener noreferrer" aria-label={t('settings.brand.open')}>
                  <ExternalLink />
                </a>
              </Button>
            </div>
          ) : (
            <Skeleton className="h-10 w-full" />
          )}
          {logoOmitted && (
            <p className="flex items-start gap-2 rounded-xl bg-warning/10 px-3 py-2 text-xs font-medium text-warning ring-1 ring-inset ring-warning/25">
              <TriangleAlert className="mt-0.5 h-3.5 w-3.5 shrink-0" />
              {t('settings.brand.logoOmitted')}
            </p>
          )}
          <p className="flex items-start gap-2 text-sm leading-relaxed text-muted-foreground">
            <Info className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
            {t('settings.brand.explain')}
          </p>
        </div>
        <div className={cn('relative overflow-hidden p-4', TILE)}>
          <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(80%_70%_at_50%_0%,hsl(var(--primary)/0.14),transparent_70%)]" />
          <p className="relative mb-3 text-2xs font-semibold uppercase tracking-[0.14em] text-muted-foreground">{t('settings.brand.preview')}</p>
          <div className="relative flex flex-col items-center gap-2 rounded-xl bg-card p-4 text-center shadow-glass ring-1 ring-border/50">
            <SchoolLogo school={logoOmitted ? { ...school, logo: null } : school} className="h-12 w-12" />
            <p className="line-clamp-2 text-sm font-semibold">{school.name}</p>
            <p className="text-xs text-muted-foreground">{school.city}</p>
          </div>
        </div>
      </div>
    </SectionCard>
  );
}
