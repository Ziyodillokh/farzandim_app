'use client';

import { useRouter } from 'next/navigation';
import { useCallback } from 'react';

import { useCan } from '@/auth/use-session';
import type { Scope } from '@/data/contracts';
import { regionName } from '@/data/reference/regions';
import { useI18n } from '@/i18n';

/**
 * Doira matnlari: bo'linmalar sarlavhasi (hududlar / tumanlar), xarita bo'limi
 * nomi va doira nomi (respublika yoki hudud).
 */
export function useScopeLabels(scope: Scope) {
  const { t, locale } = useI18n();
  const national = scope.kind === 'NATIONAL';
  return {
    national,
    areasHeader: national ? t('nav.regions') : t('common.districtsTitle'),
    mapTitle: national ? t('dashboard.sections.map') : t('dashboard.sections.districts'),
    scopeName: national ? t('common.national') : regionName(scope.regionId, locale, true),
  };
}

/**
 * Bo'linma qatorini bosish: faqat respublika doirasida va `regions.view`
 * ruxsati bo'lsa — hudud profiliga o'tadi; aks holda `undefined`.
 */
export function useAreaDrill(scope: Scope): ((id: string) => void) | undefined {
  const router = useRouter();
  const can = useCan();
  const open = useCallback((id: string) => router.push(`/regions/view?id=${encodeURIComponent(id)}`), [router]);
  return scope.kind === 'NATIONAL' && can('regions.view') ? open : undefined;
}
