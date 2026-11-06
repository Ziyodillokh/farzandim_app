// Ota-onalarga push (Parvoz Parents): har foydalanuvchiga o'z tilida, cheklangan
// parallellik bilan. Natija — FCM qabul qildimi (`sent > 0`); token yo'q yoki
// xato — yetkazilmagan. Push xatosi hech qachon chaqiruvchini yiqitmaydi.

import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService, PushPayload } from '../../common/fcm/fcm.service';
import { mapLimit } from '../../common/helpers/map-limit';
import type { NotifLang } from '../../common/i18n/notification-i18n';

/** Bir vaqtda nechta foydalanuvchiga push yuboriladi. */
const PUSH_CONCURRENCY = 8;

export { mapLimit };

@Injectable()
export class CommsPushService {
  private readonly logger = new Logger(CommsPushService.name);

  constructor(
    private readonly fcm: FcmService,
    private readonly prisma: PrismaService,
  ) {}

  /** Har foydalanuvchiga bitta push; `userId → yetkazildimi`. Takroriy id'lar birlashtiriladi. */
  async sendToUsers(userIds: readonly string[], build: (lang: NotifLang) => PushPayload): Promise<Map<string, boolean>> {
    const unique = [...new Set(userIds)];
    const outcomes = await mapLimit(unique, PUSH_CONCURRENCY, async (userId) => [userId, await this.sendOne(userId, build)] as const);
    return new Map(outcomes);
  }

  /** Bitta foydalanuvchiga push; `true` — FCM qabul qildi. */
  async sendOne(userId: string, build: (lang: NotifLang) => PushPayload): Promise<boolean> {
    try {
      const lang = await this.fcm.getUserLang(userId);
      const result = await this.fcm.sendPushToUser(userId, build(lang));
      return result.sent > 0;
    } catch (err) {
      this.logger.warn(`maktab push yuborilmadi: ${String(err)}`);
      return false;
    }
  }

  /** Push sarlavhasi uchun maktab nomi (qisqa nom bo'lsa — shu). */
  async schoolLabel(schoolId: string): Promise<string> {
    const school = await this.prisma.school.findUnique({
      where: { id: schoolId },
      select: { name: true, shortName: true },
    });
    return school?.shortName || school?.name || '';
  }
}
