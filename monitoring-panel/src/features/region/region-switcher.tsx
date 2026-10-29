'use client';

import { MapPin } from 'lucide-react';
import { useRouter } from 'next/navigation';

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { REGIONS, type RegionId } from '@/data/reference/regions';
import { useI18n } from '@/i18n';

/** Profil ichida boshqa hududga o'tish (respublika foydalanuvchisi uchun). */
export function RegionSwitcher({ value }: { value: RegionId }) {
  const { t, locale } = useI18n();
  const router = useRouter();
  return (
    <Select value={value} onValueChange={(id) => router.push(`/regions/view?id=${id}`)}>
      <SelectTrigger
        aria-label={t('region.switch')}
        className="h-10 w-[220px] gap-2 rounded-xl border-white/20 bg-white/10 text-white shadow-none hover:bg-white/15 [&>svg:last-child]:text-white/70"
      >
        <MapPin className="h-4 w-4 text-cyan-200" />
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {REGIONS.map((r) => (
          <SelectItem key={r.id} value={r.id}>
            {locale === 'ru' ? r.nameRu : r.nameUz}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
