'use client';

import { useQueryClient } from '@tanstack/react-query';
import { useEffect } from 'react';

import { toLocalIso } from '@/data/mock/calendar';
import { clockNow } from '@/data/mock/clock';
import { transact } from '@/data/mock/db';
import { decodeBrand } from '@/lib/brand-link';

/** Havoladagi `#b=` brendini maktab profiliga qo'llaydi va fragmentni tozalaydi. */
export function BrandFromUrl() {
  const queryClient = useQueryClient();
  useEffect(() => {
    const brand = decodeBrand(window.location.hash);
    if (!brand) return;
    transact((t) => {
      const before = { name: t.school.name, shortName: t.school.shortName, city: t.school.city };
      t.school = { ...t.school, ...brand };
      t.audit.push({
        id: `aud-brand-${Date.now()}`,
        at: toLocalIso(clockNow()),
        actorId: 'system',
        actorName: 'Maktab havolasi',
        module: 'SETTINGS',
        action: 'school.brandLink',
        entityId: null,
        summary: `Havola orqali maktab nomi o'rnatildi: ${brand.name}`,
        before,
        after: { name: brand.name, shortName: brand.shortName, city: brand.city },
      });
    });
    history.replaceState(null, '', window.location.pathname + window.location.search);
    void queryClient.invalidateQueries();
  }, [queryClient]);
  return null;
}
