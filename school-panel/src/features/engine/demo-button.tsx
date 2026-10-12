'use client';

import { useI18n } from '@/i18n';

/** Topbardagi ko'rinadigan "Demo" tugmasi — demo panelni ochadi (agent C to'ldiradi). */
export function DemoButton() {
  const { t } = useI18n();
  return (
    <span className="hidden rounded-full border border-warning/30 bg-warning/10 px-2.5 py-1 text-2xs font-semibold text-warning 2xl:inline">
      {t('common.demoBadge')}
    </span>
  );
}
