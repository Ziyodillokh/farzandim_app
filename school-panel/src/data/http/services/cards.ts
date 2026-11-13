import type { AssignedCard, CardStatus, CardTapLog, CardTapView, SchoolCard } from '@/data/contracts';
import type { cardsService } from '@/data/mock/services/cards';
import type { CardAssignInput, CardBlockInput, CardTapInput } from '@/data/schemas/cards';
import { http } from '../client';

const BASE = '/school/cards';
const id = (v: string) => encodeURIComponent(v);

/** NFC kartalar — backend `CardsController` va kiosk `card-tap`. */
export const cardsHttp: typeof cardsService = {
  list: async (status?: CardStatus) => (await http<{ items: SchoolCard[] }>('GET', BASE, { query: { status } })).items,
  assign: (input: CardAssignInput) => http<AssignedCard>('POST', BASE, { body: input }),
  block: (cardId: string, input: CardBlockInput) => http<SchoolCard>('POST', `${BASE}/${id(cardId)}/block`, { body: input }),
  unblock: (cardId: string) => http<SchoolCard>('POST', `${BASE}/${id(cardId)}/unblock`),
  remove: (cardId: string) => http<void>('DELETE', `${BASE}/${id(cardId)}`),
  taps: async (options = {}) =>
    (
      await http<{ items: CardTapLog[] }>('GET', `${BASE}/taps`, {
        query: { suspicious: options.suspicious === undefined ? undefined : String(options.suspicious), limit: options.limit },
      })
    ).items,
  tap: (input: CardTapInput) => http<CardTapView>('POST', '/school/attendance/kiosk/card-tap', { body: input }),
};
