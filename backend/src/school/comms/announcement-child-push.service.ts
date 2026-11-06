// E'lon yuborilganda (`audience.includeStudents = true`) ilovasi ulangan bolalarga push. Har (e'lon, bola) uchun
// BIR marta (`child_push_dedupe`): qayta urinish / qayta chaqirish dublikat yubormaydi. Hech qachon e'lonni yuborishni
// yiqitmaydi; token yo'q bola jim o'tkaziladi; logda e'lon matni va bola ma'lumoti yo'q.

import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { ChildPushDedupeService } from '../../common/notification-prefs/child-push-dedupe.service';
import { errorLabel } from '../../common/notification-prefs/error-label';
import {
  announcementChildPush,
  childRecipientsWhere,
  selectRecipients,
  SCHOOL_ANNOUNCEMENT_DEDUPE_KIND,
} from './announcement-child-push';
import { CommsPushService, mapLimit } from './comms-push.service';
import { toAudience } from './comms-roster';

const PUSH_CONCURRENCY = 8;

@Injectable()
export class AnnouncementChildPushService {
  private readonly logger = new Logger(AnnouncementChildPushService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: CommsPushService,
    private readonly dedupe: ChildPushDedupeService,
  ) {}

  /** Yuborilgan e'lonni bolalarga yetkazish; xato yutiladi (log). Qaytadi: FCM qabul qilgan bolalar soni. */
  async notify(announcementId: string): Promise<number> {
    try {
      return await this.notifyOrThrow(announcementId);
    } catch (err) {
      this.logger.error(`e'lon bolalarga push xatosi: ${errorLabel(err)}`);
      return 0;
    }
  }

  private async notifyOrThrow(announcementId: string): Promise<number> {
    const a = await this.prisma.schoolAnnouncement.findUnique({ where: { id: announcementId } });
    if (!a || a.status !== 'SENT') return 0;
    const where = childRecipientsWhere(a.schoolId, toAudience(a.audience));
    if (!where) return 0;
    const rows = await this.prisma.schoolStudent.findMany({
      where,
      select: {
        childId: true,
        child: { select: { childUserId: true, notificationPreference: { select: { schoolAnnouncements: true, hideText: true } } } },
      },
    });
    const recipients = selectRecipients(rows);
    if (recipients.length === 0) return 0;
    const claimed = new Set(await this.dedupe.claim(recipients.map((r) => r.childId), SCHOOL_ANNOUNCEMENT_DEDUPE_KIND, a.id));
    const targets = recipients.filter((r) => claimed.has(r.childId));
    if (targets.length === 0) return 0;
    const school = targets.some((t) => !t.hideText) ? await this.push.schoolLabel(a.schoolId) : '';
    const delivered = await mapLimit(targets, PUSH_CONCURRENCY, (t) =>
      this.push.sendOne(t.childUserId, (lang) => announcementChildPush(lang, { id: a.id, school, title: a.title, hideText: t.hideText })),
    );
    return delivered.filter(Boolean).length;
  }
}
