'use client';

import { Landmark, MapPin } from 'lucide-react';

import { useSession } from '@/auth/use-session';
import { Select, SelectContent, SelectItem, SelectSeparator, SelectTrigger, SelectValue } from '@/components/ui/select';
import type { Scope } from '@/data/contracts';
import { isRegionId, REGIONS } from '@/data/reference/regions';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useScopeRegion } from './store';

/**
 * Sahifa doirasi: respublika foydalanuvchisi hududni tanlaydi (barcha yo'nalish
 * sahifalarida umumiy), viloyat foydalanuvchisi — doim o'z hududi.
 */
export function usePageScope(): Scope {
  const session = useSession();
  const [region] = useScopeRegion();
  if (session?.role === 'REGIONAL' && session.regionId) return { kind: 'REGION', regionId: session.regionId };
  return isRegionId(region) ? { kind: 'REGION', regionId: region } : { kind: 'NATIONAL' };
}

export function ScopeSelect({ className }: { className?: string }) {
  const { t, locale } = useI18n();
  const session = useSession();
  const [region, setRegion] = useScopeRegion();
  if (session?.role !== 'NATIONAL') return null;
  const value = isRegionId(region) ? region : 'ALL';
  return (
    <Select value={value} onValueChange={setRegion}>
      <SelectTrigger aria-label={t('nav.regions')} className={cn('h-9 w-[230px] gap-2 rounded-xl', className)}>
        {value === 'ALL' ? <Landmark className="h-4 w-4 text-primary" /> : <MapPin className="h-4 w-4 text-primary" />}
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="ALL">{t('shell.scopeNational')}</SelectItem>
        <SelectSeparator />
        {REGIONS.map((r) => (
          <SelectItem key={r.id} value={r.id}>
            {locale === 'ru' ? r.nameRu : r.nameUz}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
