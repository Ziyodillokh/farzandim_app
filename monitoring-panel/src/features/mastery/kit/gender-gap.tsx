'use client';

import { useI18n } from '@/i18n';
import { useMetricFormat } from '@/lib/format';
import { Inset } from './layout';
import { gap } from './num';

/**
 * Ikki guruh farqi matni: "Farq: 2,0 p.p. — qiz bolalar natijasi yuqoriroq".
 * Farq `threshold` dan kichik bo'lsa — "sezilarli farq yo'q". Bolalar bir-biriga
 * qarshi qo'yilmaydi — faqat umumlashgan guruh natijasi.
 */
export function GenderGapNote({ boys, girls, unit, threshold = 0.5 }: { boys: number | null; girls: number | null; unit: string; threshold?: number }) {
  const { t } = useI18n();
  const fmt = useMetricFormat();
  const diff = gap(girls, boys);
  if (diff === null) return null;
  const verdict = Math.abs(diff) < threshold ? t('mastery.groups.noGap') : diff > 0 ? t('mastery.groups.girlsHigher') : t('mastery.groups.boysHigher');
  return (
    <Inset className="py-2.5 text-[0.8rem]">
      <b className="tabular-nums">{t('mastery.groups.gap', { value: `${fmt.num(Math.abs(diff), 1)}${unit ? ` ${unit}` : ''}` })}</b>
      <span className="text-muted-foreground"> — {verdict}</span>
    </Inset>
  );
}
