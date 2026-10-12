'use client';

import { BadgeCheck, MoreHorizontal, QrCode, RefreshCw, Send } from 'lucide-react';
import { useMemo } from 'react';

import type { Column } from '@/components/common/data-table';
import { LinkBadge } from '@/components/common/status-badges';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { clockNow } from '@/data/mock/clock';
import { useI18n } from '@/i18n';
import { initials } from '@/lib/utils';
import type { GuardianRow } from '../hooks';

const MAX_CHILD_BADGES = 3;

export type GuardianActions = {
  canLink: boolean;
  busyId: string | null;
  onInvite: (row: GuardianRow) => void;
  onShowCode: (row: GuardianRow) => void;
  onResend: (row: GuardianRow) => void;
  onSimulate: (row: GuardianRow) => void;
};

function StatusCell({ row }: { row: GuardianRow }) {
  const { t, formatDate } = useI18n();
  const expired = row.inviteExpiresAt ? new Date(row.inviteExpiresAt) < clockNow() : false;
  return (
    <div className="space-y-1">
      <LinkBadge status={row.linkStatus} />
      {row.linkStatus === 'INVITED' && row.inviteExpiresAt && (
        <p className={expired ? 'text-2xs font-medium text-destructive' : 'text-2xs text-muted-foreground'}>
          {expired ? t('parents.status.expired') : t('parents.status.expires', { date: formatDate(row.inviteExpiresAt, 'd MMM') })}
        </p>
      )}
      {row.linkStatus === 'LINKED' && row.linkedAt && (
        <p className="text-2xs text-muted-foreground">{t('parents.status.linkedAt', { date: formatDate(row.linkedAt, 'd MMM yyyy') })}</p>
      )}
    </div>
  );
}

function ActionsCell({ row, actions }: { row: GuardianRow; actions: GuardianActions }) {
  const { t } = useI18n();
  if (!actions.canLink || row.linkStatus === 'LINKED') return <span className="text-muted-foreground">—</span>;
  const busy = actions.busyId === row.id;
  return (
    <div className="flex items-center justify-end gap-1">
      {row.linkStatus === 'NOT_INVITED' ? (
        <Button size="sm" variant="soft" loading={busy} onClick={() => actions.onInvite(row)}>
          {!busy && <Send />}
          {t('parents.actions.invite')}
        </Button>
      ) : (
        <Button size="sm" variant="outline" onClick={() => actions.onShowCode(row)}>
          <QrCode />
          {t('parents.actions.showCode')}
        </Button>
      )}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon-sm" aria-label={t('parents.actions.more')} disabled={busy}>
            <MoreHorizontal />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          {row.linkStatus === 'INVITED' && (
            <DropdownMenuItem onClick={() => actions.onResend(row)}>
              <RefreshCw className="h-4 w-4" />
              {t('parents.actions.resend')}
            </DropdownMenuItem>
          )}
          <DropdownMenuItem onClick={() => actions.onSimulate(row)}>
            <BadgeCheck className="h-4 w-4" />
            {t('parents.actions.simulate')}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}

export function useGuardianColumns(actions: GuardianActions): Column<GuardianRow>[] {
  const { t } = useI18n();
  return useMemo<Column<GuardianRow>[]>(
    () => [
      {
        key: 'name',
        header: t('parents.columns.guardian'),
        sortKey: 'name',
        cell: (r) => (
          <div className="flex items-center gap-3">
            <Avatar className="h-9 w-9">
              <AvatarFallback className="bg-primary/10 text-xs font-semibold text-primary">{initials(r.fullName)}</AvatarFallback>
            </Avatar>
            <div className="min-w-0">
              <p className="truncate font-medium">{r.fullName}</p>
              <p className="truncate text-xs text-muted-foreground">{t(`enums.relation.${r.relation}`)}</p>
            </div>
          </div>
        ),
      },
      { key: 'phone', header: t('parents.columns.phone'), className: 'whitespace-nowrap tabular-nums text-muted-foreground', cell: (r) => r.phone },
      {
        key: 'children',
        header: t('parents.columns.children'),
        cell: (r) => (
          <div className="flex max-w-[280px] flex-wrap gap-1">
            {r.children.slice(0, MAX_CHILD_BADGES).map((c) => (
              <Badge key={c.id} variant="outline" className="font-medium">
                {c.name} <span className="text-muted-foreground">· {c.className}</span>
              </Badge>
            ))}
            {r.children.length > MAX_CHILD_BADGES && <Badge variant="secondary">+{r.children.length - MAX_CHILD_BADGES}</Badge>}
          </div>
        ),
      },
      { key: 'status', header: t('parents.columns.status'), sortKey: 'status', cell: (r) => <StatusCell row={r} /> },
      {
        key: 'actions',
        header: <span className="sr-only">{t('parents.columns.actions')}</span>,
        headerClassName: 'text-right',
        className: 'text-right',
        cell: (r) => <ActionsCell row={r} actions={actions} />,
      },
    ],
    [t, actions],
  );
}
