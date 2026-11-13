'use client';

import { Ban, MoreHorizontal, RotateCcw, ShieldCheck, Trash2 } from 'lucide-react';
import { useMemo } from 'react';

import { DataTable, type Column } from '@/components/common/data-table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import type { CardStatus, SchoolCard } from '@/data/contracts';
import { useI18n } from '@/i18n';

const STATUS_VARIANT: Record<CardStatus, 'success' | 'warning' | 'outline'> = { ACTIVE: 'success', LOST: 'warning', BLOCKED: 'outline' };
const KNOWN_REASONS = new Set(['REPLACED', 'LOST', 'BLOCKED']);

export type CardActions = {
  canManage: boolean;
  canBlock: boolean;
  onBlock: (card: SchoolCard) => void;
  onUnblock: (card: SchoolCard) => void;
  onRemove: (card: SchoolCard) => void;
};

/** Kartalar jadvali: raqam, o'quvchi, turi, holati, oxirgi tegish va amallar. */
export function CardsTable({ rows, loading, actions, emptyTitle, emptyDescription }: {
  rows: SchoolCard[] | undefined;
  loading?: boolean;
  actions: CardActions;
  emptyTitle: string;
  emptyDescription?: string;
}) {
  const { t, formatDate } = useI18n();

  const columns = useMemo<Column<SchoolCard>[]>(
    () => [
      {
        key: 'number',
        header: t('cards.columns.number'),
        className: 'whitespace-nowrap',
        cell: (c) => (
          <div>
            <p className="font-display font-semibold tabular-nums">{c.number}</p>
            <p className="font-mono text-2xs text-muted-foreground">{c.uid}</p>
          </div>
        ),
      },
      {
        key: 'student',
        header: t('cards.columns.student'),
        cell: (c) => (
          <div className="min-w-0">
            <p className="whitespace-nowrap font-medium">{c.studentName}</p>
            <p className="text-xs text-muted-foreground">
              {c.className} · {c.studentCode}
            </p>
          </div>
        ),
      },
      {
        key: 'kind',
        header: t('cards.columns.kind'),
        cell: (c) => (
          <Badge variant={c.kind === 'SUN' ? 'info' : 'outline'} className="gap-1" title={t(`cards.kindHint.${c.kind}`)}>
            {c.kind === 'SUN' && <ShieldCheck className="h-3 w-3" />}
            {t(`enums.cardKind.${c.kind}`)}
          </Badge>
        ),
      },
      {
        key: 'status',
        header: t('cards.columns.status'),
        cell: (c) => (
          <div>
            <Badge variant={STATUS_VARIANT[c.status]}>{t(`enums.cardStatus.${c.status}`)}</Badge>
            {c.status !== 'ACTIVE' && c.blockedReason && (
              <p className="mt-1 max-w-[14rem] truncate text-xs text-muted-foreground">
                {KNOWN_REASONS.has(c.blockedReason) ? t(`cards.reasons.${c.blockedReason as 'REPLACED' | 'LOST' | 'BLOCKED'}`) : c.blockedReason}
              </p>
            )}
          </div>
        ),
      },
      {
        key: 'lastTap',
        header: t('cards.columns.lastTap'),
        className: 'whitespace-nowrap text-sm',
        cell: (c) => (c.lastTapAt ? formatDate(new Date(c.lastTapAt), 'd MMM, HH:mm') : <span className="text-muted-foreground">{t('cards.never')}</span>),
      },
      {
        key: 'actions',
        header: '',
        className: 'w-12 text-right',
        cell: (c) => {
          const block = actions.canBlock && c.status === 'ACTIVE';
          const unblock = actions.canManage && c.status !== 'ACTIVE';
          if (!block && !unblock && !actions.canManage) return null;
          return (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon-sm" aria-label={t('common.actions')}>
                  <MoreHorizontal />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                {block && (
                  <DropdownMenuItem onClick={() => actions.onBlock(c)}>
                    <Ban className="h-4 w-4" />
                    {t('cards.block')}
                  </DropdownMenuItem>
                )}
                {unblock && (
                  <DropdownMenuItem onClick={() => actions.onUnblock(c)}>
                    <RotateCcw className="h-4 w-4" />
                    {t('cards.unblock')}
                  </DropdownMenuItem>
                )}
                {actions.canManage && (
                  <DropdownMenuItem className="text-destructive" onClick={() => actions.onRemove(c)}>
                    <Trash2 className="h-4 w-4" />
                    {t('cards.remove')}
                  </DropdownMenuItem>
                )}
              </DropdownMenuContent>
            </DropdownMenu>
          );
        },
      },
    ],
    [actions, formatDate, t],
  );

  return <DataTable columns={columns} rows={rows} rowKey={(c) => c.id} loading={loading} emptyTitle={emptyTitle} emptyDescription={emptyDescription} />;
}
