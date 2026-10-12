'use client';

import { ShieldCheck } from 'lucide-react';

import { GlassCallout } from '@/features/messages/components/glass-callout';
import { useI18n } from '@/i18n';

/** TZ 4.5 "Moliyaviy chegara": platforma to'lov qabul qilmaydi va qarz hisoblamaydi. */
export function FinanceCallout({ className }: { className?: string }) {
  const { t } = useI18n();
  return (
    <GlassCallout icon={<ShieldCheck />} title={t('reminders.payments.calloutTitle')} className={className}>
      {t('reminders.payments.callout')}
    </GlassCallout>
  );
}
