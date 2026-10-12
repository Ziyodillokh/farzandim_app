'use client';

import { Lock } from 'lucide-react';

import { useI18n } from '@/i18n';

/** Maxfiylik eslatmalari — murojaat sahifasida doim ko'rinadi. */
export function ConfidentialityCard() {
  const { t } = useI18n();
  return (
    <aside className="rounded-xl border border-primary/15 bg-primary/[0.04] p-5">
      <p className="mb-3 flex items-center gap-2 text-sm font-semibold">
        <Lock className="h-4 w-4 text-primary" />
        {t('care.request.reminders.title')}
      </p>
      <ul className="space-y-2.5 text-[0.8125rem] leading-relaxed text-foreground/80">
        {(['r1', 'r2', 'r3', 'r4'] as const).map((key) => (
          <li key={key} className="flex gap-2">
            <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-primary/60" aria-hidden />
            {t(`care.request.reminders.${key}`)}
          </li>
        ))}
      </ul>
    </aside>
  );
}
