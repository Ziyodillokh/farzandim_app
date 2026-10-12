'use client';

import { ShieldCheck } from 'lucide-react';

import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

/** TZ 4.5 "Moliyaviy chegara": platforma to'lov qabul qilmaydi va qarz hisoblamaydi. */
export function FinanceCallout({ className }: { className?: string }) {
  const { t } = useI18n();
  return (
    <div role="note" className={cn('flex gap-4 rounded-xl border border-primary/20 bg-primary/[0.05] p-4 animate-fade-in', className)}>
      <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
        <ShieldCheck className="h-5 w-5" />
      </span>
      <div className="min-w-0">
        <p className="text-sm font-semibold">{t('reminders.payments.calloutTitle')}</p>
        <p className="mt-0.5 text-sm leading-relaxed text-muted-foreground">{t('reminders.payments.callout')}</p>
      </div>
    </div>
  );
}
