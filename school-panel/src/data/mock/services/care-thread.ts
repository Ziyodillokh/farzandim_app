import type { CareMessage, CareRequest, CareStoredMessage } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { careReplySchema } from '@/data/schemas/care';
import { parseOrThrow } from '@/data/schemas/validate';
import { assertCan, currentActor, latency, newId, writeAudit } from '../context';
import { transact } from '../db';
import { nowLocalIso } from './comms-shared';

/**
 * Bola ↔ psixolog yozishmasi (kontrakt B). `care.individual`.
 * Xodim javobi BOLAGA ko'rinadi (ichki eslatma — `addRequestNote` — emas). Auditda matn, ism va murojaat ID'si yo'q.
 */
const REPLY_AUDIT = 'Bola ovozi: bolaga javob yuborildi';

export const careThreadService = {
  /**
   * Bolaga javob: birinchi javobda `repliedAt`, har safar `lastMessageAt`; holat NEW → IN_PROGRESS.
   * Yopilgan (RESOLVED) murojaatga javob yozib bo'lmaydi — 409 (avval qayta ochish kerak).
   * Haqiqiy rejimda bolaga neytral push ketadi («Sizga yangi xabar keldi»); demoda yuborilmaydi.
   */
  async replyToRequest(id: string, text: string): Promise<CareMessage> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'care.individual');
    const data = parseOrThrow(careReplySchema, { text });
    return transact((t) => {
      const request = t.careRequests.find((r) => r.id === id);
      if (!request) throw new ServiceError('NOT_FOUND', id);
      if (request.status === 'RESOLVED') throw new ServiceError('CONFLICT', 'REQUEST_CLOSED');
      const now = nowLocalIso();
      const message: CareStoredMessage = { id: newId('msg'), author: 'STAFF', staffId: actor.staffId, text: data.text, createdAt: now, readByStaffAt: now };
      const next: CareRequest = {
        ...request,
        messages: [...request.messages, message],
        status: request.status === 'NEW' ? 'IN_PROGRESS' : request.status,
        repliedAt: request.repliedAt ?? now,
        lastMessageAt: now,
        openedAt: request.openedAt ?? now,
        openedByStaffId: request.openedByStaffId ?? actor.staffId,
      };
      t.careRequests = t.careRequests.map((r) => (r.id === id ? next : r));
      writeAudit(t, actor, 'CARE', 'care.request.reply', REPLY_AUDIT);
      return { id: message.id, author: 'STAFF', authorName: actor.name, text: message.text, createdAt: now };
    });
  },
};
