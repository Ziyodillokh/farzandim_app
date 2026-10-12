'use client';

import { Progress } from '@/components/ui/progress';
import type { Announcement } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn, percent } from '@/lib/utils';

/** Yetkazildi / o'qildi ulushlari (yuborilgan xabar uchun). */
export function DeliveryStats({ stats, className }: { stats: Announcement['stats']; className?: string }) {
  const { t, formatNumber } = useI18n();
  const rows = [
    { key: 'delivered', label: t('messages.card.delivered'), value: stats.delivered, tone: 'bg-gradient-to-r from-sky-400 to-cyan-400' },
    { key: 'read', label: t('messages.card.read'), value: stats.read, tone: 'bg-gradient-to-r from-brand-400 to-brand-600' },
  ];
  return (
    <div className={cn('space-y-3', className)}>
      {rows.map((row) => {
        const pct = percent(row.value, stats.recipients);
        return (
          <div key={row.key}>
            <div className="mb-1.5 flex items-baseline justify-between gap-2 text-xs">
              <span className="text-muted-foreground">{row.label}</span>
              <span className="tabular-nums">
                <span className="font-semibold text-foreground">{formatNumber(row.value)}</span>
                <span className="text-muted-foreground"> · {pct}%</span>
              </span>
            </div>
            <Progress value={pct} className="h-1.5 bg-primary/[0.08] dark:bg-white/[0.06]" indicatorClassName={row.tone} aria-label={row.label} />
          </div>
        );
      })}
    </div>
  );
}
