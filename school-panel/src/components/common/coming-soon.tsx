'use client';

import { Construction } from 'lucide-react';

import type { TKey } from '@/i18n';
import { useI18n } from '@/i18n';
import { EmptyState } from './empty-state';
import { PageHeader } from './page-header';

/** Vaqtinchalik sahifa (modul bosqichida almashtiriladi). */
export function ComingSoon({ titleKey }: { titleKey: TKey }) {
  const { t } = useI18n();
  return (
    <>
      <PageHeader title={t(titleKey)} />
      <EmptyState icon={<Construction />} title={t(titleKey)} description="…" />
    </>
  );
}
