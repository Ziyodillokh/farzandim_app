'use client';

import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Bell, Send, Eye, MousePointerClick, CheckCheck } from 'lucide-react';
import { NotificationComposer } from '@/components/notifications/notification-composer';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { PageHeader } from '@/components/common/page-header';
import { DataPagination } from '@/components/common/data-pagination';
import { EmptyState } from '@/components/common/empty-state';
import { notificationsApi } from '@/lib/api/admin.api';
import { cn, formatCompact, formatRelative } from '@/lib/utils';
import type { AdminNotification } from '@/types/api.types';

const TARGET_LABELS: Record<string, string> = {
  all: 'Hammaga',
  parents: 'Ota-onalar',
  children: 'Bolalar',
  premium: 'Premium',
  age_group: 'Yosh guruhi',
};

const STATUS_VARIANT: Record<string, 'success' | 'warning' | 'info' | 'destructive' | 'secondary'> = {
  sent: 'success',
  scheduled: 'info',
  queued: 'warning',
  sending: 'warning',
  failed: 'destructive',
};

export default function NotificationsPage() {
  const qc = useQueryClient();
  const [page, setPage] = useState(1);
  const [composerOpen, setComposerOpen] = useState(false);
  const limit = 15;

  const { data: stats } = useQuery({
    queryKey: ['notifications-stats'],
    queryFn: () => notificationsApi.stats(),
  });

  const { data, isLoading } = useQuery({
    queryKey: ['notifications', { page, limit }],
    queryFn: () => notificationsApi.list({ page, limit }),
    placeholderData: (p) => p,
  });

  return (
    <div className="container mx-auto max-w-screen-2xl px-6 py-8">
      <PageHeader
        eyebrow="Broadcast boshqaruvi"
        title="Bildirishnomalar"
        count={data?.total}
        actions={
          <Button onClick={() => setComposerOpen(true)}>
            <Send className="h-4 w-4" /> Yangi xabar
          </Button>
        }
      />

      <NotificationComposer
        open={composerOpen}
        onOpenChange={setComposerOpen}
        onSuccess={() => {
          qc.invalidateQueries({ queryKey: ['notifications'] });
          qc.invalidateQueries({ queryKey: ['notifications-stats'] });
        }}
      />

      {/* Stats row */}
      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatTile icon={<Bell />} label="Jami yuborilgan" value={stats?.total ?? 0} color="text-primary" bg="bg-primary/10" />
        <StatTile icon={<CheckCheck />} label="Yetkazilgan" value={stats?.delivered ?? 0} color="text-info" bg="bg-info/10" />
        <StatTile icon={<Eye />} label="Ochilgan" value={stats?.opened ?? 0} color="text-warning" bg="bg-warning/10" />
        <StatTile icon={<MousePointerClick />} label="Bosilgan" value={stats?.clicked ?? 0} color="text-success" bg="bg-success/10" />
      </div>

      {/* List */}
      <Card className="overflow-hidden">
        {isLoading ? (
          <div className="divide-y divide-border">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="flex items-center gap-4 p-4">
                <Skeleton className="h-10 w-10 rounded-lg" />
                <div className="flex-1 space-y-2">
                  <Skeleton className="h-4 w-1/3" />
                  <Skeleton className="h-3 w-2/3" />
                </div>
              </div>
            ))}
          </div>
        ) : !data || data.items.length === 0 ? (
          <EmptyState icon={<Bell />} title="Bildirishnoma yo'q" description="Hozircha hech qanday broadcast yuborilmagan." />
        ) : (
          <div className="divide-y divide-border">
            {data.items.map((n) => (
              <NotificationRow key={n.id} notification={n} />
            ))}
          </div>
        )}
        {data && (
          <DataPagination page={data.page} totalPages={data.totalPages} total={data.total} limit={limit} onPageChange={setPage} />
        )}
      </Card>
    </div>
  );
}

function StatTile({ icon, label, value, color, bg }: { icon: React.ReactNode; label: string; value: number; color: string; bg: string }) {
  return (
    <Card className="p-4">
      <div className={cn('mb-3 flex h-10 w-10 items-center justify-center rounded-lg [&_svg]:size-5', bg, color)}>
        {icon}
      </div>
      <p className="text-xs font-medium text-muted-foreground">{label}</p>
      <p className="mt-1 text-2xl font-bold tabular-nums">{formatCompact(value)}</p>
    </Card>
  );
}

function NotificationRow({ notification: n }: { notification: AdminNotification }) {
  return (
    <div className="flex items-start gap-4 p-4 transition-colors hover:bg-accent/40">
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
        <Bell className="h-5 w-5" />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <p className="truncate font-semibold">{n.title}</p>
          <Badge variant={STATUS_VARIANT[n.status] ?? 'secondary'} size="sm">{n.status}</Badge>
          <Badge variant="outline" size="sm">{TARGET_LABELS[n.targetType] ?? n.targetType}</Badge>
        </div>
        <p className="mt-0.5 line-clamp-1 text-sm text-muted-foreground">{n.message}</p>
        <div className="mt-2 flex items-center gap-4 text-xs text-muted-foreground">
          <span className="flex items-center gap-1"><CheckCheck className="h-3 w-3" /> {formatCompact(n.deliveredCount)}</span>
          <span className="flex items-center gap-1"><Eye className="h-3 w-3" /> {formatCompact(n.openedCount)}</span>
          <span className="flex items-center gap-1"><MousePointerClick className="h-3 w-3" /> {formatCompact(n.clickedCount)}</span>
          <span className="ml-auto">{formatRelative(n.sentAt ?? n.createdAt)}</span>
        </div>
      </div>
    </div>
  );
}
