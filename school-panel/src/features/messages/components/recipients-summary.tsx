'use client';

import { MessageSquareText, Smartphone } from 'lucide-react';
import type { ReactNode } from 'react';

import { Skeleton } from '@/components/ui/skeleton';
import type { AudienceReach } from '@/data/mock/services/comms';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';

/** Qamrov: o'quvchi / ota-ona soni va Parvoz push ↔ SMS zaxira taqsimoti. */
export function RecipientsSummary({ reach, loading, className }: { reach: AudienceReach | undefined; loading?: boolean; className?: string }) {
  const { t, formatNumber } = useI18n();
  if (loading && !reach) return <Skeleton className={cn('h-28 w-full rounded-xl', className)} />;
  if (!reach || reach.guardians === 0) {
    return <p className={cn('rounded-xl border border-dashed p-4 text-center text-sm text-muted-foreground', className)}>{t('messages.recipients.empty')}</p>;
  }
  const pushPct = percent(reach.linked, reach.guardians);
  return (
    <div className={cn('space-y-4', className)}>
      <div className="grid grid-cols-2 gap-3">
        <Metric label={t('messages.recipients.guardians')} value={formatNumber(reach.guardians)} />
        <Metric label={t('messages.recipients.students')} value={formatNumber(reach.students)} />
      </div>
      <div className="flex h-2.5 overflow-hidden rounded-full bg-muted" role="img" aria-label={`${t('messages.recipients.push')} ${pushPct}%`}>
        <div className="h-full bg-primary transition-all duration-500" style={{ width: `${pushPct}%` }} />
        <div className="h-full bg-warning/70 transition-all duration-500" style={{ width: `${100 - pushPct}%` }} />
      </div>
      <div className="grid gap-2 sm:grid-cols-2">
        <Channel icon={<Smartphone />} tone="bg-primary/10 text-primary" label={t('messages.recipients.push')} hint={t('messages.recipients.pushHint')} value={formatNumber(reach.linked)} pct={pushPct} />
        <Channel icon={<MessageSquareText />} tone="bg-warning/15 text-warning" label={t('messages.recipients.sms')} hint={t('messages.recipients.smsHint')} value={formatNumber(reach.sms)} pct={100 - pushPct} />
      </div>
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-muted/60 px-3 py-2.5">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-0.5 font-display text-xl font-semibold tabular-nums">{value}</p>
    </div>
  );
}

function Channel({ icon, tone, label, hint, value, pct }: { icon: ReactNode; tone: string; label: string; hint: string; value: string; pct: number }) {
  return (
    <div className="flex items-center gap-3 rounded-xl border px-3 py-2.5">
      <span className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-lg [&_svg]:size-4', tone)}>{icon}</span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium">{label}</p>
        <p className="truncate text-2xs text-muted-foreground">{hint}</p>
      </div>
      <div className="text-right">
        <p className="font-semibold tabular-nums">{value}</p>
        <p className="text-2xs text-muted-foreground tabular-nums">{pct}%</p>
      </div>
    </div>
  );
}
