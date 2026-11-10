'use client';

import { keepPreviousData, useQuery } from '@tanstack/react-query';

import { api } from '@/data/api';
import type { PaymentFilter, ReminderFilter, VerificationFilter } from '@/data/mock/services/comms';
import type {
  PaymentBulkCreateInput,
  PaymentBulkShiftInput,
  PaymentCreateInput,
  PaymentShiftInput,
  ReminderInput,
  VerificationAnswerInput,
} from '@/data/schemas/comms';
import { useCommsMutation } from '@/features/messages/hooks';
import { useI18n } from '@/i18n';

export const reminderKeys = {
  list: (filter: ReminderFilter) => ['comms', 'reminders', filter] as const,
  payments: (filter: PaymentFilter) => ['comms', 'payments', 'list', filter] as const,
  paymentStats: (classId?: string) => ['comms', 'payments', 'stats', classId ?? 'all'] as const,
  history: (id: string) => ['comms', 'payments', 'history', id] as const,
  verifications: (filter: VerificationFilter) => ['comms', 'verifications', filter] as const,
};

export function useReminders(filter: ReminderFilter) {
  return useQuery({ queryKey: reminderKeys.list(filter), queryFn: () => api.comms.reminders.list(filter), placeholderData: keepPreviousData });
}

export function usePayments(filter: PaymentFilter) {
  return useQuery({ queryKey: reminderKeys.payments(filter), queryFn: () => api.comms.payments.list(filter), placeholderData: keepPreviousData });
}

/** Ko'rsatkichlar — ro'yxat bilan bir xil sinf filtri bo'yicha. */
export function usePaymentStats(classId?: string) {
  return useQuery({
    queryKey: reminderKeys.paymentStats(classId),
    queryFn: () => api.comms.payments.stats({ classId }),
    placeholderData: keepPreviousData,
  });
}

export function usePaymentHistory(id: string | null) {
  return useQuery({ queryKey: reminderKeys.history(id ?? ''), queryFn: () => api.comms.payments.history(id ?? ''), enabled: Boolean(id) });
}

export function useVerifications(filter: VerificationFilter, enabled = true) {
  return useQuery({ queryKey: reminderKeys.verifications(filter), queryFn: () => api.comms.verifications.list(filter), placeholderData: keepPreviousData, enabled });
}

export function useCreateReminder() {
  return useCommsMutation((input: ReminderInput) => api.comms.reminders.create(input), 'reminders.toasts.created');
}

export function useUpdateReminder() {
  return useCommsMutation(({ id, input }: { id: string; input: ReminderInput }) => api.comms.reminders.update(id, input), 'reminders.toasts.updated');
}

export function useRemoveReminder() {
  return useCommsMutation((id: string) => api.comms.reminders.remove(id), 'reminders.toasts.deleted');
}

export function useToggleReminder() {
  const { t } = useI18n();
  return useCommsMutation(
    ({ id, active }: { id: string; active: boolean }) => api.comms.reminders.setActive(id, active),
    (r) => t(r.active ? 'reminders.toasts.activated' : 'reminders.toasts.paused'),
  );
}

export function useShiftPayment() {
  return useCommsMutation(({ id, input }: { id: string; input: PaymentShiftInput }) => api.comms.payments.shift(id, input), 'reminders.payments.toasts.shifted');
}

export function useBulkShift() {
  const { t } = useI18n();
  return useCommsMutation((input: PaymentBulkShiftInput) => api.comms.payments.bulkShift(input), (r) => t('reminders.payments.toasts.bulkShifted', { count: r.updated }));
}

export function useCreatePayment() {
  return useCommsMutation((input: PaymentCreateInput) => api.comms.payments.create(input), 'reminders.payments.toasts.created');
}

export function useBulkCreatePayments() {
  const { t } = useI18n();
  return useCommsMutation(
    (input: PaymentBulkCreateInput) => api.comms.payments.bulkCreate(input),
    (r) => t('reminders.payments.toasts.bulkCreated', { created: r.created, skipped: r.skipped, noGuardian: r.noGuardian }),
  );
}

export function usePausePayment() {
  return useCommsMutation(({ id, note }: { id: string; note: string }) => api.comms.payments.pause(id, { note }), 'reminders.payments.toasts.paused');
}

export function useResumePayment() {
  return useCommsMutation(({ id, note }: { id: string; note: string }) => api.comms.payments.resume(id, { note }), 'reminders.payments.toasts.resumed');
}

export function useAnswerVerification() {
  return useCommsMutation(({ id, input }: { id: string; input: VerificationAnswerInput }) => api.comms.verifications.answer(id, input), 'reminders.verifications.toasts.answered');
}

export function useCloseVerification() {
  return useCommsMutation((id: string) => api.comms.verifications.close(id), 'reminders.verifications.toasts.closed');
}
