'use client';

import { Plus, Search } from 'lucide-react';
import { useMemo, useState } from 'react';

import { Can } from '@/auth/can';
import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { ErrorState } from '@/components/common/error-state';
import { PageHeader } from '@/components/common/page-header';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Switch } from '@/components/ui/switch';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { CardStatus, SchoolCard } from '@/data/contracts';
import { AssignCardDialog } from '@/features/cards/components/assign-card-dialog';
import { CardsTable, type CardActions } from '@/features/cards/components/cards-table';
import { TapsTable } from '@/features/cards/components/taps-table';
import { useBlockCard, useCards, useCardTaps, useRemoveCard, useUnblockCard } from '@/features/cards/hooks';
import { useI18n } from '@/i18n';
import { normalizeSearch } from '@/lib/normalize-search';

type View = 'cards' | 'taps';
type StatusFilter = CardStatus | 'ALL';
const STATUS_FILTERS: readonly StatusFilter[] = ['ALL', 'ACTIVE', 'LOST', 'BLOCKED'];

function matches(card: SchoolCard, term: string): boolean {
  if (!term) return true;
  return [card.studentName, card.studentCode, card.number, card.uid].some((v) => normalizeSearch(v).includes(term));
}

/** NFC kartalar: biriktirish, yo'qolganini bloklash va kiosk tegishlari jurnali. */
export default function CardsPage() {
  const { t } = useI18n();
  const can = useCan();
  const [view, setView] = useState<View>('cards');
  const [status, setStatus] = useState<StatusFilter>('ALL');
  const [query, setQuery] = useState('');
  const [suspiciousOnly, setSuspiciousOnly] = useState(false);
  const [assignOpen, setAssignOpen] = useState(false);
  const [blocking, setBlocking] = useState<SchoolCard | null>(null);
  const [removing, setRemoving] = useState<SchoolCard | null>(null);

  const cards = useCards(status === 'ALL' ? undefined : status);
  const taps = useCardTaps(suspiciousOnly ? true : undefined);
  const block = useBlockCard();
  const unblock = useUnblockCard();
  const remove = useRemoveCard();

  const term = normalizeSearch(query.trim());
  const rows = useMemo(() => cards.data?.filter((c) => matches(c, term)), [cards.data, term]);
  const actions = useMemo<CardActions>(
    () => ({
      canManage: can('students.manage'),
      canBlock: can('students.manage') || can('attendance.mark'),
      onBlock: setBlocking,
      onUnblock: (card) => unblock.mutate(card.id),
      onRemove: setRemoving,
    }),
    [can, unblock],
  );

  return (
    <>
      <PageHeader
        title={t('cards.title')}
        subtitle={t('cards.subtitle')}
        actions={
          <Can perm="students.manage">
            <Button onClick={() => setAssignOpen(true)}>
              <Plus />
              {t('cards.assign')}
            </Button>
          </Can>
        }
      />

      <Tabs value={view} onValueChange={(v) => setView(v === 'taps' ? 'taps' : 'cards')} className="mb-4">
        <TabsList>
          <TabsTrigger value="cards">{t('cards.tabCards')}</TabsTrigger>
          <TabsTrigger value="taps">{t('cards.tabTaps')}</TabsTrigger>
        </TabsList>
      </Tabs>

      {view === 'cards' ? (
        <>
          <div className="mb-4 flex flex-wrap items-center gap-3">
            <div className="relative w-full max-w-sm">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('cards.search')} className="pl-9" />
            </div>
            <div className="flex flex-wrap gap-1.5">
              {STATUS_FILTERS.map((s) => (
                <Button key={s} size="sm" variant={status === s ? 'soft' : 'ghost'} onClick={() => setStatus(s)}>
                  {s === 'ALL' ? t('cards.statusAll') : t(`enums.cardStatus.${s}`)}
                </Button>
              ))}
            </div>
          </div>
          {cards.error ? (
            <ErrorState error={cards.error} onRetry={() => void cards.refetch()} />
          ) : (
            <CardsTable
              rows={rows}
              loading={cards.isLoading}
              actions={actions}
              emptyTitle={term || status !== 'ALL' ? t('cards.emptyFiltered') : t('cards.empty')}
              emptyDescription={term || status !== 'ALL' ? undefined : t('cards.emptyText')}
            />
          )}
        </>
      ) : (
        <>
          <label className="mb-4 flex w-fit cursor-pointer items-center gap-2.5 text-sm">
            <Switch checked={suspiciousOnly} onCheckedChange={setSuspiciousOnly} />
            {t('cards.taps.suspiciousOnly')}
          </label>
          {taps.error ? <ErrorState error={taps.error} onRetry={() => void taps.refetch()} /> : <TapsTable rows={taps.data} loading={taps.isLoading} />}
        </>
      )}

      <AssignCardDialog open={assignOpen} onOpenChange={setAssignOpen} />
      <ConfirmDialog
        open={Boolean(blocking)}
        onOpenChange={(open) => !open && setBlocking(null)}
        title={t('cards.blockTitle')}
        description={blocking ? t('cards.blockText', { number: blocking.number, name: blocking.studentName }) : undefined}
        confirmLabel={t('cards.block')}
        destructive
        loading={block.isPending}
        onConfirm={() => blocking && block.mutate({ id: blocking.id, input: { reason: 'LOST' } }, { onSuccess: () => setBlocking(null) })}
      />
      <ConfirmDialog
        open={Boolean(removing)}
        onOpenChange={(open) => !open && setRemoving(null)}
        title={t('cards.removeTitle')}
        description={removing ? t('cards.removeText', { number: removing.number, name: removing.studentName }) : undefined}
        confirmLabel={t('cards.remove')}
        destructive
        loading={remove.isPending}
        onConfirm={() => removing && remove.mutate(removing.id, { onSuccess: () => setRemoving(null) })}
      />
    </>
  );
}
