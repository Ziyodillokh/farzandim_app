'use client';

import { ChevronRight } from 'lucide-react';
import Link from 'next/link';

import { SectionCard } from '@/components/common/section-card';
import { CareStatusBadge, UrgencyBadge } from '@/components/common/status-badges';
import { Button } from '@/components/ui/button';
import type { DashboardOverview } from '@/data/mock/services/dashboard';
import { useI18n } from '@/i18n';

export function CareInboxCard({ inbox }: { inbox: NonNullable<DashboardOverview['careInbox']> }) {
  const { t, formatRelative } = useI18n();
  return (
    <SectionCard
      title={t('dashboard.careInbox.title')}
      description={t('dashboard.careInbox.subtitle')}
      actions={
        <Button asChild variant="ghost" size="sm">
          <Link href="/care/requests">{t('dashboard.upcoming.all')}</Link>
        </Button>
      }
      bodyClassName="p-2"
    >
      {inbox.recent.length === 0 ? (
        <p className="px-4 py-10 text-center text-sm text-muted-foreground">{t('dashboard.careInbox.empty')}</p>
      ) : (
        <ul>
          {inbox.recent.map((r) => (
            <li key={r.id}>
              <Link href={`/care/requests/view?id=${r.id}`} className="group flex items-center gap-3 rounded-lg px-3 py-3 hover:bg-muted/60">
                <div className="min-w-0 flex-1">
                  <p className="flex flex-wrap items-center gap-2 text-sm font-medium">
                    {r.studentName}
                    <span className="text-xs font-normal text-muted-foreground">{r.className}</span>
                  </p>
                  <p className="mt-0.5 text-xs text-muted-foreground">
                    {t(`enums.careTopicTag.${r.topic}`)} · {formatRelative(r.createdAt)}
                  </p>
                </div>
                {r.urgency === 'URGENT' && <UrgencyBadge urgency={r.urgency} />}
                <CareStatusBadge status={r.status} />
                <ChevronRight className="h-4 w-4 text-muted-foreground" />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </SectionCard>
  );
}
