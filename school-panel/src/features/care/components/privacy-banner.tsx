'use client';

import { Clock3, EyeOff, Lock, Stethoscope, Users } from 'lucide-react';
import type { ReactNode } from 'react';

import { useI18n } from '@/i18n';
import { CARE_MIN_GROUP } from '@/lib/k-anon';

function Point({ icon, children }: { icon: ReactNode; children: ReactNode }) {
  return (
    <li className="flex items-start gap-2.5">
      <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-lg bg-card/80 text-primary shadow-soft [&_svg]:size-3.5">
        {icon}
      </span>
      <span className="text-[0.8125rem] leading-relaxed text-foreground/80">{children}</span>
    </li>
  );
}

/** Bola ovozi maxfiylik banneri: anonim, k ≥ 5, tashxis yo'q, favqulodda xizmat emas. */
export function PrivacyBanner() {
  const { t } = useI18n();
  return (
    <section
      aria-label={t('care.privacy.title')}
      className="mb-6 overflow-hidden rounded-xl border border-primary/15 bg-gradient-to-br from-primary/[0.07] via-card to-success/[0.06] p-5 shadow-soft animate-fade-in"
    >
      <div className="mb-3 flex items-center gap-2.5">
        <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary/10 text-primary">
          <Lock className="h-4 w-4" />
        </span>
        <h2 className="font-semibold">{t('care.privacy.title')}</h2>
      </div>
      <ul className="grid gap-3 md:grid-cols-2">
        <Point icon={<EyeOff />}>{t('care.privacy.anonymous')}</Point>
        <Point icon={<Users />}>{t('care.privacy.kAnon', { k: CARE_MIN_GROUP })}</Point>
        <Point icon={<Stethoscope />}>{t('care.privacy.noDiagnosis')}</Point>
        <Point icon={<Clock3 />}>{t('care.privacy.notEmergency')}</Point>
      </ul>
    </section>
  );
}
