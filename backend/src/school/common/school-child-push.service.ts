// Maktab -> bolaga NEYTRAL push, har (bola, tur, kalit) uchun BIR marta (`child_push_dedupe`): qayta
// urinish, cron va parallel server nusxalari dublikat yubormaydi. Push xatosi hech qachon chaqiruvchini
// yiqitmaydi; tokeni yo'q bola jim o'tkaziladi; logda bola ma'lumoti va mazmun yo'q.

import { Injectable, Logger, Module } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { FcmModule } from '../../common/fcm/fcm.module';
import { FcmService, PushPayload } from '../../common/fcm/fcm.service';
import { mapLimit } from '../../common/helpers/map-limit';
import type { NotifLang } from '../../common/i18n/notification-i18n';
import { ChildPushDedupeService } from '../../common/notification-prefs/child-push-dedupe.service';
import { errorLabel } from '../../common/notification-prefs/error-label';
import { NotificationPrefsModule } from '../../common/notification-prefs/notification-prefs.module';

/** Bir vaqtda nechta bolaga push yuboriladi. */
const PUSH_CONCURRENCY = 8;

export interface ChildRecipient {
  childId: string;
  childUserId: string;
}

/**
 * Maktab ma'lumotini bola ilovasida KO'RADIGAN o'quvchilar (`findEnrolledStudent` qoidasi): arxivlanmagan,
 * sinfi bor, maktab faol, bola ilovasi ulangan va "maktab / sinf noto'g'ri" so'rovi ochiq emas.
 */
export const enrolledChildWhere = (schoolId: string) =>
  ({
    schoolId,
    archived: false,
    classId: { not: null },
    childId: { not: null },
    child: { childUserId: { not: null } },
    school: { status: 'ACTIVE' },
    linkCorrections: { none: { status: 'OPEN' } },
  }) satisfies Prisma.SchoolStudentWhereInput;

export interface RecipientRow {
  childId: string | null;
  child: { childUserId: string | null } | null;
}

/** Ilovasi ulangan bolalar, takrorsiz. */
export function toRecipients(rows: readonly RecipientRow[]): ChildRecipient[] {
  const byChild = new Map<string, ChildRecipient>();
  for (const { childId, child } of rows) {
    if (childId && child?.childUserId) byChild.set(childId, { childId, childUserId: child.childUserId });
  }
  return [...byChild.values()];
}

@Injectable()
export class SchoolChildPushService {
  private readonly logger = new Logger(SchoolChildPushService.name);

  constructor(
    private readonly fcm: FcmService,
    private readonly dedupe: ChildPushDedupeService,
  ) {}

  /** `(kind, refKey)` bo'yicha hali olmagan bolalarga push. Qaytadi: FCM qabul qilgan bolalar soni. */
  async sendOnce(
    recipients: readonly ChildRecipient[],
    kind: string,
    refKey: string,
    build: (lang: NotifLang) => PushPayload,
  ): Promise<number> {
    if (recipients.length === 0) return 0;
    try {
      const unique = [...new Map(recipients.map((r) => [r.childId, r])).values()];
      const claimed = new Set(await this.dedupe.claim(unique.map((r) => r.childId), kind, refKey));
      const targets = unique.filter((r) => claimed.has(r.childId));
      const delivered = await mapLimit(targets, PUSH_CONCURRENCY, (t) => this.sendOne(t.childUserId, build));
      return delivered.filter(Boolean).length;
    } catch (err) {
      this.logger.error(`maktab bolaga push xatosi (${kind}): ${errorLabel(err)}`);
      return 0;
    }
  }

  private async sendOne(userId: string, build: (lang: NotifLang) => PushPayload): Promise<boolean> {
    try {
      const lang = await this.fcm.getUserLang(userId);
      return (await this.fcm.sendPushToUser(userId, build(lang))).sent > 0;
    } catch (err) {
      this.logger.warn(`maktab bolaga push yuborilmadi: ${errorLabel(err)}`);
      return false;
    }
  }
}

@Module({
  imports: [FcmModule, NotificationPrefsModule],
  providers: [SchoolChildPushService],
  exports: [SchoolChildPushService],
})
export class SchoolChildPushModule {}
