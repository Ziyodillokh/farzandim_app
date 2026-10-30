'use client';

import { BookOpen, Map as MapIcon } from 'lucide-react';
import Link from 'next/link';
import type { ReactNode } from 'react';

import { Section } from '@/components/common/section';
import type { MetricKey, Scope } from '@/data/contracts';
import { K_MIN } from '@/data/mock/model/engine';
import { MapPanel } from '@/features/map/map-panel';
import { useI18n } from '@/i18n';

/** Respublika doirasi — hudud foydalanuvchisi uchun taqqoslash so'rovlari (kesh umumiy). */
export const NATIONAL_SCOPE: Scope = { kind: 'NATIONAL' };

/**
 * Xarita bo'limi: respublikada — 14 hudud, hudud doirasida — tumanlar.
 * `scroll-mt-32` — sahifa navigatsiyasi (yopishqoq panel) bo'lim tepasini yopmasin.
 */
export function MapSection({ id, scope, metrics, initial }: { id: string; scope: Scope; metrics: readonly MetricKey[]; initial: MetricKey }) {
  const { t } = useI18n();
  const national = scope.kind === 'NATIONAL';
  return (
    <Section
      id={id}
      className="scroll-mt-32"
      icon={<MapIcon />}
      title={national ? t('map.title') : t('map.districtsTitle')}
      subtitle={national ? t('dashboard.mapSub') : t('wellbeing.kit.mapSubDistrict')}
    >
      <MapPanel scope={scope} metrics={metrics} initial={initial} />
    </Section>
  );
}

/** Sahifa oxiridagi izohlar: maxfiylik, qo'shimcha qatorlar va metodologiya havolasi. */
export function PageFootnote({ children }: { children?: ReactNode }) {
  const { t } = useI18n();
  return (
    <footer className="space-y-1.5 rounded-2xl bg-primary/[0.04] p-4 text-[0.72rem] leading-relaxed text-muted-foreground ring-1 ring-inset ring-border/50 dark:bg-white/[0.02]">
      <p>
        <b className="text-foreground">{t('common.privacy.title')}.</b> {t('common.privacy.text', { k: K_MIN })}
      </p>
      {children}
      <p>
        <Link href="/methodology" className="inline-flex items-center gap-1 font-semibold text-primary hover:underline">
          <BookOpen className="h-3.5 w-3.5" />
          {t('wellbeing.kit.methodology')}
        </Link>
      </p>
    </footer>
  );
}
