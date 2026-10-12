'use client';

import { BellRing } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';

export function UpcomingCard({ items }: { items: NonNullable<DashboardOverview['upcoming']> }) {
  const { t, formatDate } = useI18n();
  return (
    <SectionCard
      title={t('dashboard.upcoming.title')}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/reminders">{t('dashboard.upcoming.all')}</Link>
        </Button>
      }
      bodyClassName="p-2"
    >
      {items.length === 0 ? (
        <p className="px-4 py-10 text-center text-sm text-muted-foreground">{t('dashboard.upcoming.empty')}</p>
      ) : (
        <ul>
          {items.map((r) => (
            <li key={r.id} className="flex items-start gap-3 rounded-lg px-3 py-2.5">
              <div className="flex w-11 shrink-0 flex-col items-center rounded-lg bg-primary/10 py-1 text-primary">
                <span className="font-display text-base font-semibold leading-tight">{formatDate(r.sendAt, 'd')}</span>
                <span className="text-[0.65rem] uppercase">{formatDate(r.sendAt, 'MMM')}</span>
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">{r.title}</p>
                <p className="mt-0.5 flex items-center gap-1 text-xs text-muted-foreground">
                  <BellRing className="h-3 w-3" />
                  {t(`enums.reminderKind.${r.kind}`)} · {formatDate(r.sendAt, 'HH:mm')}
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
