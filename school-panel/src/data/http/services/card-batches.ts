import type { AssignedCard, CardImportSummary, CardReservation, CardReserveResult } from '@/data/contracts';
import type { cardBatchService } from '@/data/mock/services/card-batches';
import type { CardBindInput, CardImportInput, CardReserveInput } from '@/data/schemas/cards';
import { http } from '../client';

const BASE = '/school/cards';
const id = (v: string) => encodeURIComponent(v);

/** Karta partiyasi — backend `CardsController` (`reservations`, `import`). */
export const cardBatchHttp: typeof cardBatchService = {
  list: async () => (await http<{ items: CardReservation[] }>('GET', `${BASE}/reservations`)).items,
  reserve: (input: CardReserveInput) => http<CardReserveResult>('POST', `${BASE}/reservations`, { body: input }),
  cancel: (reservationId: string) => http<void>('DELETE', `${BASE}/reservations/${id(reservationId)}`),
  bind: (reservationId: string, input: CardBindInput) => http<AssignedCard>('POST', `${BASE}/reservations/${id(reservationId)}/bind`, { body: input }),
  importBindings: (input: CardImportInput) => http<CardImportSummary>('POST', `${BASE}/import`, { body: input }),
};
