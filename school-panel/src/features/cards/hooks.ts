'use client';

import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { CardStatus } from '@/data/contracts';
import type { CardAssignInput, CardBlockInput, CardTapInput } from '@/data/schemas/cards';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

/** Tegishlar jurnali kiosk ishlayotganda yangilanib turadi. */
const TAPS_MS = 5_000;

export const cardKeys = {
  all: ['cards'] as const,
  list: (status: CardStatus | undefined) => ['cards', 'list', status ?? 'all'] as const,
  taps: (suspicious: boolean | undefined) => ['cards', 'taps', suspicious ?? 'all'] as const,
};

export function useCards(status?: CardStatus) {
  return useQuery({ queryKey: cardKeys.list(status), queryFn: () => api.cards.list(status), placeholderData: keepPreviousData });
}

export function useCardTaps(suspicious?: boolean) {
  return useQuery({
    queryKey: cardKeys.taps(suspicious),
    queryFn: () => api.cards.taps({ suspicious, limit: 100 }),
    refetchInterval: TAPS_MS,
    placeholderData: keepPreviousData,
  });
}

/** Karta o'zgarishi — kartalar va davomat ro'yxatlari yangilanadi; xato toast bilan. */
function useCardMutation<TVars, TResult>(fn: (vars: TVars) => Promise<TResult>, onDone?: (result: TResult) => void) {
  const queryClient = useQueryClient();
  const { t } = useI18n();
  return useMutation({
    mutationFn: fn,
    onSuccess: (result) => {
      void queryClient.invalidateQueries({ queryKey: cardKeys.all });
      onDone?.(result);
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

export function useAssignCard() {
  const { t } = useI18n();
  return useCardMutation(
    (input: CardAssignInput) => api.cards.assign(input),
    (card) =>
      toast.success(
        card.replacedNumber ? t('cards.assignedReplaced', { number: card.number, old: card.replacedNumber }) : t('cards.assigned', { number: card.number }),
      ),
  );
}

export function useBlockCard() {
  const { t } = useI18n();
  return useCardMutation(
    ({ id, input }: { id: string; input: CardBlockInput }) => api.cards.block(id, input),
    () => toast.success(t('cards.blocked')),
  );
}

export function useUnblockCard() {
  const { t } = useI18n();
  return useCardMutation(
    (id: string) => api.cards.unblock(id),
    () => toast.success(t('cards.unblocked')),
  );
}

export function useRemoveCard() {
  const { t } = useI18n();
  return useCardMutation(
    (id: string) => api.cards.remove(id),
    () => toast.success(t('cards.removed')),
  );
}

/** Kiosk tegishi: natija ekranda katta kartochkada (toast emas); davomat ro'yxatlari yangilanadi. */
export function useCardTap() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CardTapInput) => api.cards.tap(input),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['attendance'] });
      void queryClient.invalidateQueries({ queryKey: cardKeys.all });
    },
  });
}
