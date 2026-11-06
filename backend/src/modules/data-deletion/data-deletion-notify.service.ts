// Ma'lumotlarni o'chirish so'rovi yaratilgach xabar berish (best-effort: har biri alohida yutiladi).
//  - ota-onaga NEYTRAL push (bola ismi yo'q; `data.childId` orqali ilova kerakli bolani ochadi);
//  - bola maktab o'quvchisiga bog'langan bo'lsa — direktor va administratorga saqlangan bildirishnoma:
//    FAQAT `{ studentName, className }` (sabab, bola id'si, boshqa ma'lumot yo'q);
//  - audit yozuvi (bola id'sidan boshqa ma'lumotsiz).
// Hech narsa avtomatik o'chirilmaydi. Logda ism / id yo'q.

import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { tr } from '../../common/i18n/notification-i18n';
import { errorLabel } from '../../common/notification-prefs/error-label';
import { DATA_DELETION_NOTIFICATION_KIND, deletionNotificationId } from './data-deletion-purge';

export const DATA_DELETION_PUSH_TYPE = 'DATA_DELETION_REQUEST';
/** Saqlangan bildirishnoma qaysi rollarga ko'rinadi. */
export const DATA_DELETION_STAFF_ROLES = ['DIRECTOR', 'ADMIN'];

export interface DeletionRequestEvent {
  requestId: string;
  createdAt: Date;
  childId: string;
  parentId: string;
  /** So'rovni yuborgan bola foydalanuvchisi (audit uchun). */
  actorUserId: string;
  request?: { ip?: string; headers?: Record<string, string | string[] | undefined> };
}

@Injectable()
export class DataDeletionNotifyService {
  private readonly logger = new Logger(DataDeletionNotifyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
    private readonly audit: AuditService,
  ) {}

  async afterCreate(event: DeletionRequestEvent): Promise<void> {
    await this.safely('audit', () =>
      this.audit.log(event.actorUserId, 'child', 'DATA_DELETION_REQUEST', event.requestId, { childId: event.childId }, event.request),
    );
    await this.safely('parent push', () => this.pushParent(event));
    await this.safely('staff notification', () => this.notifySchoolStaff(event));
  }

  private async pushParent(event: DeletionRequestEvent): Promise<void> {
    const lang = await this.fcm.getUserLang(event.parentId);
    await this.fcm.sendPushToUser(event.parentId, {
      title: tr(lang, 'push.neutralTitle'),
      body: tr(lang, 'dataDeletion.body'),
      data: { type: DATA_DELETION_PUSH_TYPE, childId: event.childId },
    });
  }

  private async notifySchoolStaff(event: DeletionRequestEvent): Promise<void> {
    const student = await this.prisma.schoolStudent.findUnique({
      where: { childId: event.childId },
      select: { schoolId: true, lastName: true, firstName: true, class: { select: { name: true } } },
    });
    if (!student) return;
    const id = deletionNotificationId(event.requestId);
    const data = {
      schoolId: student.schoolId,
      kind: DATA_DELETION_NOTIFICATION_KIND,
      at: event.createdAt,
      roles: DATA_DELETION_STAFF_ROLES,
      classIds: [],
      staffIds: [],
      params: { studentName: `${student.lastName} ${student.firstName}`, className: student.class?.name ?? '' },
    };
    await this.prisma.schoolStaffNotification.upsert({ where: { id }, create: { id, ...data }, update: data });
  }

  private async safely(step: string, run: () => Promise<unknown>): Promise<void> {
    try {
      await run();
    } catch (err) {
      this.logger.warn(`o'chirish so'rovi: ${step} bajarilmadi: ${errorLabel(err)}`);
    }
  }
}
