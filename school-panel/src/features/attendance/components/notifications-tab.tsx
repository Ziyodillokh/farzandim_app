'use client';

import { BellRing, CheckCheck, XCircle } from 'lucide-react';
import { useMemo, useState } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { PhoneMockup, PhoneNotification } from '@/components/common/phone-mockup';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import type { ParentNotification } from '@/data/contracts';
import { paginate } from '@/data/mock/query';
import { useI18n } from '@/i18n';
import { useParentNotifications } from '../hooks';

type Row = ParentNotification & { studentName: string; className: string; guardianName: string };

const PAGE_SIZE = 25;
const PREVIEW_COUNT = 4;

/** "Farzandingiz keldi/ketdi" — ota-onalarga yuborilgan xabarlar jurnali + telefon maketi. */
export function NotificationsTab({ classFilter }: { classFilter?: string }) {
  const { t, formatDate } = useI18n();
  const [page, setPage] = useState(1);
  const query = useParentNotifications();
  const rows = useMemo(() => (query.data ?? []).filter((n) => !classFilter || n.className === classFilter), [query.data, classFilter]);
  const paged = query.data ? paginate(rows, page, PAGE_SIZE) : undefined;

  const columns = useMemo<Column<Row>[]>(
    () => [
      { key: 'time', header: t('attendance.notifications.columns.time'), className: 'w-20 font-semibold tabular-nums', cell: (n) => formatDate(n.at, 'HH:mm') },
      {
        key: 'student',
        header: t('attendance.notifications.columns.student'),
        cell: (n) => (
          <div>
            <p className="whitespace-nowrap font-medium">{n.studentName}</p>
            <p className="text-xs text-muted-foreground">{n.className}</p>
          </div>
        ),
      },
      { key: 'guardian', header: t('attendance.notifications.columns.guardian'), className: 'text-muted-foreground', cell: (n) => n.guardianName },
      { key: 'message', header: t('attendance.notifications.columns.message'), cell: (n) => t(`attendance.notifications.kind.${n.kind}`) },
      {
        key: 'delivery',
        header: t('attendance.notifications.columns.delivery'),
        cell: (n) =>
          n.delivered ? (
            <Badge variant="success">
              <CheckCheck className="h-3 w-3" />
              {t('attendance.notifications.delivered')}
            </Badge>
          ) : (
            <Badge variant="destructive">
              <XCircle className="h-3 w-3" />
              {t('attendance.notifications.notDelivered')}
            </Badge>
          ),
      },
    ],
    [t, formatDate],
  );

  if (query.error) return <ErrorState error={query.error} onRetry={() => void query.refetch()} />;

  return (
    <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,1fr)_340px]">
      <div className="min-w-0">
        <p className="mb-3 flex items-center gap-2 rounded-xl bg-primary/[0.06] px-3.5 py-2.5 text-sm text-muted-foreground ring-1 ring-inset ring-primary/10">
          <BellRing className="h-4 w-4 shrink-0 text-primary" />
          {t('attendance.notifications.hint')}
        </p>
        <DataTable
          columns={columns}
          rows={paged?.items}
          rowKey={(n) => n.id}
          loading={query.isLoading}
          pagination={paged?.pagination}
          onPageChange={setPage}
          emptyTitle={t('attendance.notifications.empty')}
        />
      </div>
      <Card className="relative hidden overflow-hidden px-4 pb-6 pt-5 xl:sticky xl:top-24 xl:block">
        <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(70%_45%_at_50%_30%,hsl(var(--primary)/0.16),transparent_70%)]" />
        <p className="relative mb-4 flex items-center justify-center gap-2 text-xs font-semibold uppercase tracking-[0.16em] text-muted-foreground">
          <BellRing className="h-3.5 w-3.5 text-primary" />
          {t('attendance.notifications.previewTitle')}
        </p>
        <PhoneMockup time={formatDate(new Date(), 'HH:mm')} className="relative">
          {rows.slice(0, PREVIEW_COUNT).map((n) => (
            <PhoneNotification
              key={n.id}
              meta={`Parvoz Parents · ${formatDate(n.at, 'HH:mm')}`}
              title={t(`attendance.notifications.kind.${n.kind}`)}
              body={`${n.studentName} · ${n.className}`}
              important={n.kind === 'ABSENT' || n.kind === 'EARLY_EXIT'}
            />
          ))}
        </PhoneMockup>
      </Card>
    </div>
  );
}
