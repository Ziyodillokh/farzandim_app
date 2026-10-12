'use client';

import { MessageSquareText, Smartphone } from 'lucide-react';
import type { ReactNode } from 'react';

import { Skeleton } from '@/components/ui/skeleton';
import type { AudienceReach } from '@/data/mock/services/comms';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';
import { ICON_TONES, INNER_TILE } from '../styles';

/** Qamrov: o'quvchi / ota-ona soni va Parvoz push ↔ SMS zaxira taqsimoti. */
export function RecipientsSummary({ reach, loading, className }: { reach: AudienceReach | undefined; loading?: boolean; className?: string }) {
  const { t, formatNumber } = useI18n();
  if (loading && !reach) return <Skeleton className={cn('h-28 w-full rounded-xl', className)} />;
  if (!reach || reach.guardians === 0) {
    return (
      <p className={cn(INNER_TILE, 'p-4 text-center text-sm text-muted-foreground', className)}>
        {t('messages.recipients.empty')}
      </p>
    );
  }
  const pushPct = percent(reach.linked, reach.guardians);
  return (
    <div className={cn('space-y-4', className)}>
      <div className="grid grid-cols-2 gap-3">
        <Metric label={t('messages.recipients.guardians')} value={formatNumber(reach.guardians)} />
        <Metric label={t('messages.recipients.students')} value={formatNumber(reach.students)} />
      </div>
      <div className="flex h-2 gap-0.5 overflow-hidden rounded-full" role="img" aria-label={`${t('messages.recipients.push')} ${pushPct}%`}>
        <div className="h-full rounded-full bg-gradient-to-r from-brand-400 to-brand-600 transition-all duration-500" style={{ width: `${pushPct}%` }} />
        <div className="h-full flex-1 rounded-full bg-gradient-to-r from-sky-300 to-cyan-400 transition-all duration-500 dark:from-sky-500/70 dark:to-cyan-500/70" />
      </div>
      <div className="grid gap-2">
        <Channel icon={<Smartphone />} tone={ICON_TONES.primary} label={t('messages.recipients.push')} hint={t('messages.recipients.pushHint')} value={formatNumber(reach.linked)} pct={pushPct} />
        <Channel icon={<MessageSquareText />} tone={ICON_TONES.cyan} label={t('messages.recipients.sms')} hint={t('messages.recipients.smsHint')} value={formatNumber(reach.sms)} pct={100 - pushPct} />
      </div>
    </div>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className={cn(INNER_TILE, 'px-3 py-2.5')}>
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 font-display text-xl font-semibold tracking-[-0.02em] tabular-nums">{value}</p>
    </div>
  );
}

function Channel({ icon, tone, label, hint, value, pct }: { icon: ReactNode; tone: string; label: string; hint: string; value: string; pct: number }) {
  return (
    <div className={cn(INNER_TILE, 'flex items-center gap-3 px-3 py-2.5')}>
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
