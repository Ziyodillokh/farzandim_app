'use client';

import { BellRing, Map, ShieldCheck } from 'lucide-react';

import { DemoBadge } from '@/components/common/demo-badge';
import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
import { OFFICIAL_NATIONAL } from '@/data/reference/official-stats';
import { useI18n } from '@/i18n';

/** Login chap qismi: brend, shior, uchta imkoniyat va rasmiy statistikadan uchta raqam. */
export function LoginHero() {
  const { t, formatNumber } = useI18n();
  const points = [
    { icon: Map, text: t('auth.heroPoints.map') },
    { icon: BellRing, text: t('auth.heroPoints.signals') },
    { icon: ShieldCheck, text: t('auth.heroPoints.privacy') },
  ];
  const stats = [
    { value: formatNumber(OFFICIAL_NATIONAL.pupils), label: t('auth.heroStats.pupils') },
    { value: formatNumber(OFFICIAL_NATIONAL.schools), label: t('auth.heroStats.schools') },
    { value: '14', label: t('auth.heroStats.regions') },
  ];
  return (
    <div className="hidden max-w-[640px] text-white lg:block animate-fade-in">
      <div className="flex items-center gap-3">
        <ParvozWordmark size="xl" sub="Monitoring" tone="onDark" />
      </div>
      <p className="mt-10 text-2xs font-semibold uppercase tracking-[0.22em] text-brand-300">{t('auth.heroEyebrow')}</p>
      <p className="mt-3 font-display text-[2.6rem] font-semibold leading-[1.08] tracking-[-0.03em]">
        <span className="text-gradient-brand">{t('auth.heroTitle')}</span>
      </p>
      <p className="mt-5 max-w-[34rem] text-[1.02rem] leading-relaxed text-white/70">{t('auth.heroText')}</p>
      <ul className="mt-8 space-y-3">
        {points.map(({ icon: Icon, text }) => (
          <li key={text} className="flex items-center gap-3 text-[0.95rem] text-white/85">
            <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-white/[0.06] text-brand-300 ring-1 ring-inset ring-white/10">
              <Icon className="h-[18px] w-[18px]" />
            </span>
            {text}
          </li>
        ))}
      </ul>
      <dl className="mt-10 grid max-w-[34rem] grid-cols-3 gap-3">
        {stats.map((s) => (
          <div key={s.label} className="rounded-2xl bg-white/[0.04] px-4 py-3 ring-1 ring-inset ring-white/[0.08]">
            <dt className="sr-only">{s.label}</dt>
            <dd className="font-display text-[1.35rem] font-semibold tabular-nums text-white">{s.value}</dd>
            <dd className="mt-0.5 text-xs text-white/60">{s.label}</dd>
          </div>
        ))}
      </dl>
      <div className="mt-6">
        <DemoBadge tone="onDark" />
      </div>
    </div>
  );
}
