'use client';

import { Apple, CalendarOff, PhoneCall, ShieldCheck, TimerOff, type LucideIcon } from 'lucide-react';

import { Card } from '@/components/ui/card';
import { type TKey, useI18n } from '@/i18n';

const RULES: ReadonlyArray<[LucideIcon, TKey]> = [
  [TimerOff, 'schoolMode.safety.autoEnd'],
  [PhoneCall, 'schoolMode.safety.alwaysOpen'],
  [CalendarOff, 'schoolMode.safety.holidays'],
  [Apple, 'schoolMode.safety.ios'],
];

/** Xavfsizlik qoidalari (TZ 4.2) — har School Mode sahifasida ko'rinadigan eslatma. */
export function SafetyCallout({ className }: { className?: string }) {
  const { t } = useI18n();
  return (
    <Card className={className}>
      <div className="flex items-center gap-2 border-b px-5 py-4">
        <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-success/10 text-success">
          <ShieldCheck className="h-4 w-4" aria-hidden />
        </span>
        <h2 className="text-[0.95rem] font-semibold">{t('schoolMode.safety.title')}</h2>
      </div>
      <ul className="grid gap-4 p-5 sm:grid-cols-2">
        {RULES.map(([Icon, key]) => (
          <li key={key} className="flex gap-3 text-sm">
            <Icon className="mt-0.5 h-4 w-4 shrink-0 text-primary" aria-hidden />
            <span className="text-muted-foreground">{t(key)}</span>
          </li>
        ))}
      </ul>
    </Card>
  );
}
