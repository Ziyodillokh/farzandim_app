'use client';

import { BellRing, CalendarDays } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { ICON_CHIP, TILE } from '../lib/tile';

export function UpcomingCard({ items }: { items: NonNullable<DashboardOverview['upcoming']> }) {
  const { t, formatDate } = useI18n();
  return (
    <SectionCard
      title={t('dashboard.upcoming.title')}
      icon={<CalendarDays />}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/reminders">{t('dashboard.upcoming.all')}</Link>
        </Button>
      }
      bodyClassName="p-3"
    >
      {items.length === 0 ? (
        <p className="px-4 py-10 text-center text-sm text-muted-foreground">{t('dashboard.upcoming.empty')}</p>
      ) : (
        <ul className="space-y-2">
          {items.map((r) => (
            <li key={r.id} className={cn(TILE, 'flex items-center gap-3 px-2.5 py-2')}>
              <div className={cn(ICON_CHIP, 'w-11 flex-col bg-primary/10 py-1 text-primary ring-primary/15')}>
                <span className="font-display text-base font-semibold leading-tight">{formatDate(r.sendAt, 'd')}</span>
                <span className="text-[0.62rem] font-medium uppercase tracking-wide">{formatDate(r.sendAt, 'MMM')}</span>
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">{r.title}</p>
                <p className="mt-0.5 flex items-center gap-1 text-xs text-muted-foreground">
                  <BellRing className="h-3 w-3 shrink-0" />
                  <span className="truncate">
                    {t(`enums.reminderKind.${r.kind}`)} · {formatDate(r.sendAt, 'HH:mm')}
                  </span>
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
