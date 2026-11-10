// Xodim ulanish so'rovini hal qilgach (tranzaksiya yopilgandan KEYIN) ota-onaga va bolaga push.
// Push xatosi hech qachon qarorni yiqitmaydi; logda ism / maktab yo'q. Bola ilovasi ulanmagan
// (`childUserId` yo'q) bola jim o'tkaziladi.

import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { errorLabel } from '../../common/notification-prefs/error-label';
import { CommsPushService } from '../comms/comms-push.service';
import { childLinkPush, LinkNotice, parentLinkPush } from './link-decision-push';

@Injectable()
export class LinkDecisionNotifier {
  private readonly logger = new Logger(LinkDecisionNotifier.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: CommsPushService,
  ) {}

  /** Qaytadi: FCM qabul qilgan push'lar soni. */
  async send(notices: readonly LinkNotice[]): Promise<number> {
    let delivered = 0;
    for (const notice of notices) {
      try {
        if (await this.sendOne(notice)) delivered += 1;
      } catch (err) {
        this.logger.warn(`ulanish qarori push xatosi: ${errorLabel(err)}`);
      }
    }
    return delivered;
  }

  private async sendOne(notice: LinkNotice): Promise<boolean> {
    if (notice.to === 'CHILD') {
      const child = await this.prisma.child.findUnique({ where: { id: notice.childId }, select: { childUserId: true } });
      if (!child?.childUserId) return false;
      return this.push.sendOne(child.childUserId, (lang) => childLinkPush(lang, notice.event));
    }
    const school = notice.event === 'GUARDIAN_CONFIRMED' ? await this.push.schoolLabel(notice.schoolId) : '';
    return this.push.sendOne(notice.userId, (lang) => parentLinkPush(lang, notice, school));
  }
}
