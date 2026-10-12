'use client';

import { useQueryClient } from '@tanstack/react-query';
import { useEffect } from 'react';

import { transact } from '@/data/mock/db';
import { decodeBrand } from '@/lib/brand-link';

/** Havoladagi `#b=` brendini maktab profiliga qo'llaydi va fragmentni tozalaydi. */
export function BrandFromUrl() {
  const queryClient = useQueryClient();
  useEffect(() => {
    const brand = decodeBrand(window.location.hash);
    if (!brand) return;
    transact((t) => {
      t.school = { ...t.school, ...brand };
    });
    history.replaceState(null, '', window.location.pathname + window.location.search);
    void queryClient.invalidateQueries();
  }, [queryClient]);
  return null;
}
