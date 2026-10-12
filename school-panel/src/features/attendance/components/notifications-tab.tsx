'use client';

import { BellRing, CheckCheck, XCircle } from 'lucide-react';
import { useMemo, useState } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { ErrorState } from '@/components/common/error-state';
import { PhoneMockup, PhoneNotification } from '@/components/common/phone-mockup';
import { Badge } from '@/components/ui/badge';
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
            <p className="font-medium">{n.studentName}</p>
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
    <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,1fr)_320px]">
      <div className="min-w-0">
        <p className="mb-3 flex items-center gap-2 text-sm text-muted-foreground">
          <BellRing className="h-4 w-4 text-primary" />
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
      <div className="hidden xl:block xl:sticky xl:top-24">
        <p className="mb-3 text-center text-xs font-semibold uppercase tracking-wider text-muted-foreground">{t('attendance.notifications.previewTitle')}</p>
        <PhoneMockup time={formatDate(new Date(), 'HH:mm')}>
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
      </div>
    </div>
  );
}
