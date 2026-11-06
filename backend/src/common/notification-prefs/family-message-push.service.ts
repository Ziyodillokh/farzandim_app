// Oila xabari push'ini bola sozlamalariga ko'ra yuboradi (ovoz / matn / media / video uchun umumiy).
// Push hech qachon xabar yuborishni yiqitmaydi; logda mazmun va yuboruvchi yo'q.

import { Injectable, Logger } from '@nestjs/common';
import { FcmService } from '../fcm/fcm.service';
import { errorLabel } from './error-label';
import { buildFamilyMessagePush, FamilyMessagePushInput } from './family-message-push';
import { NotificationPrefsService } from './notification-prefs.service';

export interface FamilyMessagePushRequest {
  link: { childId: string; childUserId: string };
  receiverId: string;
  shown: FamilyMessagePushInput['shown'];
  data: FamilyMessagePushInput['data'];
}

@Injectable()
export class FamilyMessagePushService {
  private readonly logger = new Logger(FamilyMessagePushService.name);

  constructor(
    private readonly fcm: FcmService,
    private readonly prefs: NotificationPrefsService,
  ) {}

  /** Bola qabul qilsa — sozlamalarga ko'ra; ota-ona qabul qilsa — odatdagidek (sozlamalar bola qurilmalari uchun). */
  async send(request: FamilyMessagePushRequest): Promise<void> {
    const { link, receiverId, shown, data } = request;
    try {
      if (receiverId !== link.childUserId) {
        await this.fcm.sendPushToUser(receiverId, { ...shown, data });
        return;
      }
      const [prefs, lang] = await Promise.all([this.prefs.forChild(link.childId), this.fcm.getUserLang(receiverId)]);
      const payload = buildFamilyMessagePush({ prefs, lang, shown, data });
      if (payload) await this.fcm.sendPushToUser(receiverId, payload);
    } catch (err) {
      this.logger.warn(`oila xabari push yuborilmadi (${request.data.type}): ${errorLabel(err)}`);
    }
  }
}
