// Oila xabari (matn / ovoz / video / media) push'ini BOLAGA qurish — sof funksiya.
// `familyMessages = false` -> umuman yuborilmaydi; `hideText = true` -> neytral ("Parvoz" / "Yangi xabar"),
// yuboruvchi va mazmunsiz (data'da ham `senderId` yo'q). SOS va qo'ng'iroqlar bu yerdan o'tmaydi.

import type { PushPayload } from '../fcm/fcm.service';
import { NotifLang, tr } from '../i18n/notification-i18n';
import type { ResolvedPrefs } from './notification-prefs';

export interface FamilyMessagePushInput {
  prefs: Pick<ResolvedPrefs, 'familyMessages' | 'hideText'>;
  lang: NotifLang;
  /** Odatdagi (yashirilmagan) push: sarlavha — yuboruvchi ismi, matn — qisqa mazmun. */
  shown: { title: string; body: string };
  data: { type: 'voice' | 'video'; messageId: string; senderId: string };
}

/** `null` — push yuborilmaydi. */
export function buildFamilyMessagePush(input: FamilyMessagePushInput): PushPayload | null {
  const { prefs, lang, shown, data } = input;
  if (!prefs.familyMessages) return null;
  if (!prefs.hideText) return { ...shown, data };
  return {
    title: tr(lang, 'push.neutralTitle'),
    body: tr(lang, 'familyMessage.body'),
    data: { type: data.type, messageId: data.messageId },
  };
}
