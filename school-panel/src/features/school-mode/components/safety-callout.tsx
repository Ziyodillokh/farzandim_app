'use client';

import { Apple, CalendarOff, PhoneCall, ShieldCheck, TimerOff, type LucideIcon } from 'lucide-react';

import { SectionCard } from '@/components/common/section-card';
import { type TKey, useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { TILE, TONE_ORB } from '../lib';

const RULES: ReadonlyArray<[LucideIcon, TKey]> = [
  [TimerOff, 'schoolMode.safety.autoEnd'],
  [PhoneCall, 'schoolMode.safety.alwaysOpen'],
  [CalendarOff, 'schoolMode.safety.holidays'],
  [Apple, 'schoolMode.safety.ios'],
];

/** Xavfsizlik qoidalari (TZ 4.2) — School Mode sahifalarida ko'rinadigan eslatma. */
export function SafetyCallout({ className }: { className?: string }) {
  const { t } = useI18n();
  return (
    <SectionCard className={className} icon={<ShieldCheck />} title={t('schoolMode.safety.title')} bodyClassName="p-4 sm:p-5">
      <ul className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {RULES.map(([Icon, key]) => (
          <li key={key} className={cn('flex gap-3 p-3.5 text-sm', TILE)}>
            <span className={cn('flex h-8 w-8 shrink-0 items-center justify-center rounded-lg ring-1 ring-inset', TONE_ORB.primary)}>
              <Icon className="h-4 w-4" aria-hidden />
            </span>
            <span className="leading-relaxed text-muted-foreground">{t(key)}</span>
          </li>
        ))}
      </ul>
    </SectionCard>
  );
}
