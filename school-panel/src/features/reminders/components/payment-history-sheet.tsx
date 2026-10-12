'use client';

import { CalendarCog, CalendarPlus, CirclePause, CirclePlay, Layers, ShieldCheck, type LucideIcon } from 'lucide-react';

import { EmptyState } from '@/components/common/empty-state';
import { ErrorState } from '@/components/common/error-state';
import { Badge } from '@/components/ui/badge';
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { Skeleton } from '@/components/ui/skeleton';
import type { PaymentReminderEntry } from '@/data/contracts';
import type { PaymentRow } from '@/data/mock/services/comms';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { usePaymentHistory } from '../hooks';

const ACTION_STYLE: Record<PaymentReminderEntry['action'], { icon: LucideIcon; tone: string }> = {
  CREATED: { icon: CalendarPlus, tone: 'bg-muted text-muted-foreground' },
  SHIFTED: { icon: CalendarCog, tone: 'bg-primary/10 text-primary' },
  PAUSED: { icon: CirclePause, tone: 'bg-warning/15 text-warning' },
  RESUMED: { icon: CirclePlay, tone: 'bg-success/10 text-success' },
  BULK_SHIFT: { icon: Layers, tone: 'bg-info/10 text-info' },
  VERIFIED: { icon: ShieldCheck, tone: 'bg-success/10 text-success' },
};

/** Oila eslatmasining o'zgarishlar tarixi (kim, qachon, nima uchun). */
export function PaymentHistorySheet({ payment, onOpenChange }: { payment: PaymentRow | null; onOpenChange: (open: boolean) => void }) {
  const { t, tc, formatDate } = useI18n();
  const history = usePaymentHistory(payment?.id ?? null);

  return (
    <Sheet open={Boolean(payment)} onOpenChange={onOpenChange}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-md">
        <SheetHeader>
          <SheetTitle className="pr-8">{t('reminders.payments.history.title')}</SheetTitle>
          <SheetDescription>{payment?.guardianName}</SheetDescription>
          {payment && (
            <div className="flex flex-wrap gap-1.5 pt-2">
              {payment.children.map((c) => (
                <Badge key={c.id} variant="outline">
                  {c.name} · {c.className}
                </Badge>
              ))}
              {payment.prepaidMonths > 0 && <Badge variant="success">{tc('reminders.payments.prepaidMonths', payment.prepaidMonths)}</Badge>}
            </div>
          )}
        </SheetHeader>
        <div className="p-6">
          {history.isError && <ErrorState error={history.error} onRetry={() => void history.refetch()} />}
          {history.isLoading && Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="mb-4 h-16 w-full rounded-xl" />)}
          {history.data?.length === 0 && <EmptyState title={t('reminders.payments.history.empty')} />}
          {history.data && history.data.length > 0 && (
            <ol className="relative space-y-5 border-l border-border pl-6">
              {history.data.map((entry, i) => {
                const { icon: Icon, tone } = ACTION_STYLE[entry.action];
                return (
                  <li key={`${entry.at}-${i}`} className="relative animate-fade-in">
                    <span className={cn('absolute -left-[37px] top-0 flex h-7 w-7 items-center justify-center rounded-full ring-4 ring-card', tone)}>
                      <Icon className="h-3.5 w-3.5" />
                    </span>
                    <p className="text-sm font-semibold">{t(`reminders.payments.history.actions.${entry.action}`)}</p>
                    <p className="mt-0.5 text-sm text-muted-foreground">{entry.note}</p>
                    <p className="mt-1 text-2xs text-muted-foreground">
                      {entry.byName} · {formatDate(entry.at, 'd MMM yyyy, HH:mm')}
                    </p>
                  </li>
                );
              })}
            </ol>
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}
