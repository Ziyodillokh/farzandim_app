'use client';

import { ChevronRight, MessageSquareHeart } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { CareStatusBadge, UrgencyBadge } from '@/components/common/status-badges';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';
import { TILE_INTERACTIVE } from '../lib/tile';

export function CareInboxCard({ inbox }: { inbox: NonNullable<DashboardOverview['careInbox']> }) {
  const { t, formatRelative } = useI18n();
  return (
    <SectionCard
      title={t('dashboard.careInbox.title')}
      description={t('dashboard.careInbox.subtitle')}
      icon={<MessageSquareHeart />}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/care/requests">{t('dashboard.upcoming.all')}</Link>
        </Button>
      }
      bodyClassName="p-3"
    >
      {inbox.recent.length === 0 ? (
        <p className="px-4 py-10 text-center text-sm text-muted-foreground">{t('dashboard.careInbox.empty')}</p>
      ) : (
        <ul className="space-y-2">
          {inbox.recent.map((r) => {
            const badges = (
              <>
                {r.urgency === 'URGENT' && <UrgencyBadge urgency={r.urgency} />}
                <CareStatusBadge status={r.status} />
              </>
            );
            return (
            <li key={r.id}>
              <Link
                href={`/care/requests/view?id=${r.id}`}
                className={cn(
                  TILE_INTERACTIVE,
                  'group flex items-center gap-3 px-3 py-2.5',
                  r.urgency === 'URGENT' && r.status === 'NEW' && 'ring-destructive/25 dark:ring-destructive/30',
                )}
              >
                <Avatar className="h-9 w-9">
                  <AvatarFallback className="bg-primary/10 text-[0.65rem] font-semibold text-primary">{initials(r.studentName)}</AvatarFallback>
                </Avatar>
                <div className="min-w-0 flex-1">
                  <p className="flex flex-wrap items-center gap-x-2 text-sm font-medium">
                    {r.studentName}
                    <span className="text-xs font-normal text-muted-foreground">{r.className}</span>
                  </p>
                  <p className="mt-0.5 truncate text-xs text-muted-foreground">
                    {t(`enums.careTopicTag.${r.topic}`)} · {formatRelative(r.createdAt)}
                  </p>
                  <span className="mt-1.5 flex flex-wrap gap-1.5 sm:hidden">{badges}</span>
                </div>
                <span className="hidden shrink-0 items-center gap-1.5 sm:flex">{badges}</span>
                <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
              </Link>
            </li>
            );
          })}
        </ul>
      )}
    </SectionCard>
  );
}
