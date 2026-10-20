'use client';

import { Clock3, EyeOff, Lock, Stethoscope, Users } from 'lucide-react';
import type { ReactNode } from 'react';

import { Card } from '@/components/ui/card';
import { ICON_CHIP, TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { CARE_MIN_GROUP } from '@/lib/k-anon';
import { cn } from '@/lib/utils';

function Point({ icon, children }: { icon: ReactNode; children: ReactNode }) {
  return (
    <li className={cn(TILE, 'flex items-start gap-3 px-3.5 py-3')}>
      <span className={cn(ICON_CHIP, 'mt-0.5 h-7 w-7 rounded-lg bg-sky-500/10 text-sky-600 ring-sky-500/20 dark:text-sky-300 [&_svg]:size-3.5')}>
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
    <Card aria-label={t('care.privacy.title')} className="relative mb-6 overflow-hidden p-5 animate-fade-in" role="region">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(60%_120%_at_0%_0%,hsl(var(--primary)/0.10),transparent_60%),radial-gradient(50%_100%_at_100%_100%,hsl(192_90%_50%/0.08),transparent_60%)]"
      />
      <div className="relative">
        <div className="mb-4 flex items-center gap-3">
          <span className={cn(ICON_CHIP, 'h-10 w-10 bg-primary/10 text-primary ring-primary/15')}>
            <Lock className="h-[18px] w-[18px]" />
          </span>
          <h2 className="font-semibold tracking-[-0.005em]">{t('care.privacy.title')}</h2>
        </div>
        <ul className="grid gap-2.5 md:grid-cols-2">
          <Point icon={<EyeOff />}>{t('care.privacy.anonymous')}</Point>
          <Point icon={<Users />}>{t('care.privacy.kAnon', { k: CARE_MIN_GROUP })}</Point>
          <Point icon={<Stethoscope />}>{t('care.privacy.noDiagnosis')}</Point>
          <Point icon={<Clock3 />}>{t('care.privacy.notEmergency')}</Point>
        </ul>
      </div>
    </Card>
  );
}
