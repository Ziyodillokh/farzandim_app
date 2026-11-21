'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { api } from '@/data/api';
import type { CardBindInput, CardImportInput, CardReserveInput } from '@/data/schemas/cards';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';
import { cardKeys } from './hooks';

/** `cards` ostida — kartalar o'zgarsa partiya ham yangilanadi (va aksincha). */
export const batchKeys = { list: [...cardKeys.all, 'reservations'] as const };

export function useCardReservations(enabled = true) {
  return useQuery({ queryKey: batchKeys.list, queryFn: () => api.cardBatches.list(), enabled });
}

function useInvalidateCards() {
  const queryClient = useQueryClient();
  return () => void queryClient.invalidateQueries({ queryKey: cardKeys.all });
}

export function useReserveCards() {
  const { t } = useI18n();
  const invalidate = useInvalidateCards();
  return useMutation({
    mutationFn: (input: CardReserveInput) => api.cardBatches.reserve(input),
    onSuccess: ({ created }) => {
      invalidate();
      if (created > 0) toast.success(t('cards.batch.reserved', { count: created }));
      else toast.info(t('cards.batch.reservedNone'));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

export function useCancelReservation() {
  const { t } = useI18n();
  const invalidate = useInvalidateCards();
  return useMutation({
    mutationFn: (id: string) => api.cardBatches.cancel(id),
    onSuccess: () => {
      invalidate();
      toast.success(t('cards.batch.cancelled'));
    },
    onError: (error) => toast.error(t(errorKey(error))),
  });
}

/** Ketma-ket biriktirish: natija stansiya ekranida ko'rsatiladi (toast emas). */
export function useBindReservation() {
  const invalidate = useInvalidateCards();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: CardBindInput }) => api.cardBatches.bind(id, input),
    onSuccess: invalidate,
  });
}

export function useImportCards() {
  const { t } = useI18n();
  const invalidate = useInvalidateCards();
  return useMutation({
    mutationFn: (input: CardImportInput) => api.cardBatches.importBindings(input),
    onSuccess: invalidate,
    onError: (error) => toast.error(t(errorKey(error))),
  });
}
