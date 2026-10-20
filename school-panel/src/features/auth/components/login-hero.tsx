'use client';

import { HeartHandshake, ScanLine, Smartphone } from 'lucide-react';

import { SchoolLogo } from '@/components/common/school-logo';
import { ParvozWordmark } from '@/components/layout/parvoz-wordmark';
import { useSchool } from '@/features/school/hooks';
import { useI18n } from '@/i18n';

/** Chap ustun: Parvoz brendi, maktab chipi (yagona), sarlavha va afzalliklar. */
export function LoginHero() {
  const { t } = useI18n();
  const school = useSchool().data?.school;
  const features = [
    { icon: Smartphone, text: t('auth.heroPoints.schoolMode') },
    { icon: ScanLine, text: t('auth.heroPoints.attendance') },
    { icon: HeartHandshake, text: t('auth.heroPoints.care') },
  ];

  return (
    <div className="flex flex-col items-center text-center text-white lg:items-start lg:text-left">
      <ParvozWordmark size="xl" sub="School" tone="onDark" className="hidden lg:inline-flex" />
      <ParvozWordmark size="lg" sub="School" tone="onDark" className="lg:hidden" />

      <div className="mt-6 inline-flex max-w-full items-center gap-3 rounded-2xl bg-white/[0.06] py-2 pl-2 pr-4 ring-1 ring-inset ring-white/10 backdrop-blur-md lg:mt-10">
        <SchoolLogo school={school} className="h-11 w-11 shrink-0" />
        <span className="min-w-0 text-left leading-tight">
          <span className="block truncate text-sm font-semibold">{school?.name ?? '…'}</span>
          <span className="mt-0.5 block truncate text-xs text-brand-300">{school ? `${school.city} · ${school.academicYear}` : ''}</span>
        </span>
      </div>

      <h2 className="mt-8 hidden max-w-xl font-display text-[2.15rem] font-semibold leading-[1.18] tracking-[-0.025em] lg:block">
        <span className="text-gradient-brand">{t('auth.heroTitle')}</span>
      </h2>
      <ul className="mt-8 hidden space-y-3 lg:block">
        {features.map(({ icon: Icon, text }) => (
          <li key={text} className="flex items-center gap-3 text-[0.95rem] text-white/80">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white/[0.06] text-brand-300 ring-1 ring-inset ring-white/10">
              <Icon className="h-5 w-5" />
            </span>
            {text}
          </li>
        ))}
      </ul>
      <p className="mt-12 hidden text-[0.7rem] font-semibold uppercase tracking-[0.24em] text-brand-300/80 lg:block">
        Parvoz — {t('auth.slogan')}
      </p>
    </div>
  );
}
