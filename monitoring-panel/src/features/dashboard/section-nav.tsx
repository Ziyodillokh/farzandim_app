'use client';

import { useMemo } from 'react';

import { SectionNav as BaseSectionNav } from '@/components/common/section-nav';
import { useI18n } from '@/i18n';

export const DASHBOARD_SECTIONS = ['kpis', 'map', 'insights', 'mastery', 'iq', 'interests', 'wellbeing', 'attendance', 'digital'] as const;
export type DashboardSection = (typeof DASHBOARD_SECTIONS)[number];

/** Dashboard bo'limlari navigatsiyasi (`sec-*` langarlari); hudud doirasida "Tumanlar kesimi". */
export function SectionNav({ sections = DASHBOARD_SECTIONS, districts = false }: { sections?: readonly DashboardSection[]; districts?: boolean }) {
  const { t } = useI18n();
  const items = useMemo(
    () => sections.map((s) => ({ id: `sec-${s}`, label: s === 'map' && districts ? t('dashboard.sections.districts') : t(`dashboard.sections.${s}`) })),
    [sections, districts, t],
  );
  return <BaseSectionNav items={items} label={t('dashboard.nav')} />;
}
