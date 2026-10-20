'use client';

import { Lock } from 'lucide-react';

import { Card } from '@/components/ui/card';
import { ICON_CHIP } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** Maxfiylik eslatmalari — murojaat sahifasida doim ko'rinadi. */
export function ConfidentialityCard() {
  const { t } = useI18n();
  return (
    <Card className="p-5" role="note">
      <p className="mb-3 flex items-center gap-2.5 text-sm font-semibold">
        <span className={cn(ICON_CHIP, 'h-8 w-8 rounded-lg bg-primary/10 text-primary ring-primary/15')}>
          <Lock className="h-4 w-4" />
        </span>
        {t('care.request.reminders.title')}
      </p>
      <ul className="space-y-2.5 text-[0.8125rem] leading-relaxed text-foreground/80">
        {(['r1', 'r2', 'r3', 'r4'] as const).map((key) => (
          <li key={key} className="flex gap-2">
            <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-sky-500/70" aria-hidden />
            {t(`care.request.reminders.${key}`)}
          </li>
        ))}
      </ul>
    </Card>
  );
}
