'use client';

import { CalendarCog, CirclePause, CirclePlay, Ellipsis, History, MessageCircleWarning } from 'lucide-react';
import { useMemo } from 'react';

import type { Column } from '@/components/common/data-table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import type { PaymentRow } from '@/data/mock/services/comms';
import { useI18n } from '@/i18n';

export type PaymentAction = 'shift' | 'pause' | 'resume' | 'history';

type Options = {
  rows: PaymentRow[] | undefined;
  selected: ReadonlySet<string>;
  onToggle: (id: string) => void;
  onTogglePage: (ids: string[], on: boolean) => void;
  onAction: (action: PaymentAction, row: PaymentRow) => void;
};

/** To'lov eslatmalari jadvali ustunlari (tanlash, oila, farzandlar, sana, holat, amallar). */
export function usePaymentColumns({ rows, selected, onToggle, onTogglePage, onAction }: Options): Column<PaymentRow>[] {
  const { t, tc, formatDate } = useI18n();
  const pageIds = useMemo(() => rows?.map((r) => r.id) ?? [], [rows]);
  const selectedOnPage = pageIds.filter((id) => selected.has(id)).length;
  const headerState = selectedOnPage === 0 ? false : selectedOnPage === pageIds.length ? true : 'indeterminate';

  return useMemo<Column<PaymentRow>[]>(
    () => [
      {
        key: 'select',
        headerClassName: 'w-10',
        header: (
          <Checkbox
            checked={headerState}
            onCheckedChange={() => onTogglePage(pageIds, headerState !== true)}
            aria-label={t('reminders.payments.selectAll')}
            disabled={pageIds.length === 0}
          />
        ),
        cell: (r) => <Checkbox checked={selected.has(r.id)} onCheckedChange={() => onToggle(r.id)} aria-label={t('reminders.payments.selectRow')} />,
      },
      {
        key: 'guardian',
        header: t('reminders.payments.columns.guardian'),
        sortKey: 'name',
        cell: (r) => (
          <div className="min-w-0">
            <p className="flex items-center gap-1.5 truncate font-medium">
              {r.guardianName}
              {r.openVerifications > 0 && <MessageCircleWarning className="h-3.5 w-3.5 shrink-0 text-warning" aria-label={t('reminders.payments.openVerification')} />}
            </p>
            <p className="text-xs text-muted-foreground tabular-nums">{r.phone}</p>
          </div>
        ),
      },
      {
        key: 'children',
        header: t('reminders.payments.columns.children'),
        cell: (r) => (
          <div className="flex max-w-[260px] flex-wrap gap-1">
            {r.children.map((c) => (
              <Badge key={c.id} variant="outline" className="font-normal">
                {c.name} <span className="text-muted-foreground">· {c.className}</span>
              </Badge>
            ))}
          </div>
        ),
      },
      {
        key: 'nextDate',
        header: t('reminders.payments.columns.nextDate'),
        sortKey: 'nextDate',
        className: 'whitespace-nowrap',
        cell: (r) => <span className={r.paused ? 'text-muted-foreground line-through' : 'font-medium tabular-nums'}>{formatDate(r.nextDate, 'd MMM yyyy')}</span>,
      },
      {
        key: 'prepaid',
        header: t('reminders.payments.columns.prepaid'),
        sortKey: 'prepaid',
        cell: (r) => (r.prepaidMonths > 0 ? <Badge variant="success">{tc('reminders.payments.prepaidMonths', r.prepaidMonths)}</Badge> : <span className="text-muted-foreground">—</span>),
      },
      {
        key: 'status',
        header: t('reminders.payments.columns.status'),
        cell: (r) =>
          r.paused ? (
            <Badge variant="secondary">{t('reminders.payments.status.paused')}</Badge>
          ) : r.dueSoon ? (
            <Badge variant="warning">{t('reminders.payments.status.dueSoon')}</Badge>
          ) : (
            <Badge variant="info">{t('reminders.payments.status.active')}</Badge>
          ),
      },
      {
        key: 'actions',
        header: <span className="sr-only">{t('reminders.payments.actions.menu')}</span>,
        headerClassName: 'w-12',
        cell: (r) => <RowActions row={r} onAction={onAction} />,
      },
    ],
    [t, tc, formatDate, headerState, pageIds, selected, onToggle, onTogglePage, onAction],
  );
}

function RowActions({ row, onAction }: { row: PaymentRow; onAction: Options['onAction'] }) {
  const { t } = useI18n();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon-sm" aria-label={t('reminders.payments.actions.menu')}>
          <Ellipsis />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => onAction('shift', row)}>
          <CalendarCog className="h-4 w-4" />
          {t('reminders.payments.actions.shift')}
        </DropdownMenuItem>
        {row.paused ? (
          <DropdownMenuItem onClick={() => onAction('resume', row)}>
            <CirclePlay className="h-4 w-4" />
            {t('reminders.payments.actions.resume')}
          </DropdownMenuItem>
        ) : (
          <DropdownMenuItem onClick={() => onAction('pause', row)}>
            <CirclePause className="h-4 w-4" />
            {t('reminders.payments.actions.pause')}
          </DropdownMenuItem>
        )}
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={() => onAction('history', row)}>
          <History className="h-4 w-4" />
          {t('reminders.payments.actions.history')}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
