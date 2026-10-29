'use client';

import { useCallback } from 'react';

import { findDistrict } from '@/data/mock/model/latent';
import { isRegionId, regionName } from '@/data/reference/regions';
import { useI18n } from '@/i18n';

/** Hudud yoki tuman id → joriy tildagi nom (tumanlar — rasmiy o'zbekcha nom). */
export function useAreaName() {
  const { locale } = useI18n();
  return useCallback(
    (id: string | null | undefined, opts: { short?: boolean; fallback?: string } = {}) => {
      if (!id) return opts.fallback ?? '—';
      if (isRegionId(id)) return regionName(id, locale, opts.short);
      return findDistrict(id)?.name ?? opts.fallback ?? id;
    },
    [locale],
  );
}
