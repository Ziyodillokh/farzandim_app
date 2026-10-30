'use client';

import { useCallback } from 'react';

import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';

const MILLION = 1_000_000;
const TEN_THOUSAND = 10_000;

/**
 * Qisqa son qismlari: { value: "1,91", unit: "mln" } / { "212", "ming" }
 * (ru: "млн" / "тыс."). Umumiy `fmt.compact` o'zbek tilida ham ru-RU
 * qisqartmasini ("млн") beradi — shu sabab mahalliy.
 */
export function useCompactParts() {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  return useCallback(
    (v: number | null | undefined): { value: string; unit: string } => {
      if (v === null || v === undefined) return { value: '—', unit: '' };
      if (Math.abs(v) >= MILLION) return { value: fmt.num(v / MILLION, 2), unit: t('mastery.kit.mln') };
      if (Math.abs(v) >= TEN_THOUSAND) return { value: fmt.num(v / 1000, 0), unit: t('mastery.kit.thousand') };
      return { value: fmt.count(v), unit: '' };
    },
    [fmt, t],
  );
}

/** Qisqa son matni: "1,91 mln" / "212 ming". */
export function useCompact() {
  const parts = useCompactParts();
  return useCallback(
    (v: number | null | undefined) => {
      const p = parts(v);
      return p.unit ? `${p.value} ${p.unit}` : p.value;
    },
    [parts],
  );
}
