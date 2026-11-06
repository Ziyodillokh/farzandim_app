// Ma'lumotlarni o'chirish so'rovi yaratilgach xabar berish (best-effort: har biri alohida yutiladi):
//  - audit yozuvi (bola id'sidan boshqa ma'lumotsiz; so'rov IP/User-Agent saqlanmaydi);
//  - ota-onaga NEYTRAL push (bola ismi yo'q; `data.childId` orqali ilova kerakli bolani ochadi).
// Maktab rahbariyatiga bildirishnoma bu yerda EMAS — u so'rov bilan bir tranzaksiyada yoziladi (`data-deletion-staff.ts`).
// Hech narsa avtomatik o'chirilmaydi. Logda ism / id yo'q.

import { Injectable, Logger } from '@nestjs/common';
import { AuditService } from '../../common/audit/audit.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { tr } from '../../common/i18n/notification-i18n';
import { errorLabel } from '../../common/notification-prefs/error-label';

export const DATA_DELETION_PUSH_TYPE = 'DATA_DELETION_REQUEST';

export interface DeletionRequestEvent {
  requestId: string;
  childId: string;
  parentId: string;
  /** So'rovni yuborgan bola foydalanuvchisi (audit uchun). */
  actorUserId: string;
}

@Injectable()
export class DataDeletionNotifyService {
  private readonly logger = new Logger(DataDeletionNotifyService.name);

  constructor(
    private readonly fcm: FcmService,
    private readonly audit: AuditService,
  ) {}

  async afterCreate(event: DeletionRequestEvent): Promise<void> {
    // So'rov (request) ataylab berilmaydi: IP va User-Agent auditga yozilmasin.
    await this.safely('audit', () =>
      this.audit.log(event.actorUserId, 'child', 'DATA_DELETION_REQUEST', event.requestId, { childId: event.childId }),
    );
    await this.safely('parent push', () => this.pushParent(event));
  }

  private async pushParent(event: DeletionRequestEvent): Promise<void> {
    const lang = await this.fcm.getUserLang(event.parentId);
    await this.fcm.sendPushToUser(event.parentId, {
      title: tr(lang, 'push.neutralTitle'),
      body: tr(lang, 'dataDeletion.body'),
      data: { type: DATA_DELETION_PUSH_TYPE, childId: event.childId },
    });
  }

  private async safely(step: string, run: () => Promise<unknown>): Promise<void> {
    try {
      await run();
    } catch (err) {
      this.logger.warn(`o'chirish so'rovi: ${step} bajarilmadi: ${errorLabel(err)}`);
    }
  }
}
