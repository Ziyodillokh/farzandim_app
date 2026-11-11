// Bola ovozi bildirishnomalari.
//  - Xodim tomoni: saqlangan bildirishnomalar (`SchoolStaffNotification`) — shoshilinch murojaat
//    va eskalatsiya. Faqat sinf nomi / mavzu yorlig'i: bola ismi va matn HECH QACHON yo'q.
//  - Bola tomoni: xodim javob yozganda yoki suhbat vaqtini belgilaganda NEYTRAL push ("Sizga yangi
//    xabar keldi"); so'rovnoma faollashganda — uning sinflaridagi bolalarga ("Maktabdan yangi
//    so'rovnoma"). Mazmun ham, "psixolog" so'zi ham yo'q; token bo'lmasa jim o'tkazib yuboriladi,
//    xato asosiy amalni yiqitmaydi.

import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService, PushPayload } from '../../common/fcm/fcm.service';
import { NotifLang, tr } from '../../common/i18n/notification-i18n';
import { errorLabel } from '../../common/notification-prefs/error-label';
import { enrolledChildWhere, SchoolChildPushService, toRecipients } from '../common/school-child-push.service';
import { CARE_TOPIC_LABELS, ESCALATED_SUBJECT } from './care-labels';
import { careNotificationIds, directorNotificationId, escalationNotificationId, urgentNotificationId } from './care-notification-ids';

type Tx = Prisma.TransactionClient;

/** Push `data.type` — bola ilovasi yozishmani ochishi uchun. */
export const CARE_MESSAGE_PUSH_TYPE = 'CARE_MESSAGE';
/** Push `data.type` — bola ilovasi so'rovnomani ochishi uchun. */
export const CARE_SURVEY_PUSH_TYPE = 'CARE_SURVEY';
/** `child_push_dedupe.kind` — kalit: so'rovnoma id. */
export const CARE_SURVEY_DEDUPE_KIND = 'CARE_SURVEY';

export function careSurveyPush(lang: NotifLang, survey: { id: string }): PushPayload {
  return {
    title: tr(lang, 'push.neutralTitle'),
    body: tr(lang, 'careSurvey.body'),
    data: { type: CARE_SURVEY_PUSH_TYPE, surveyId: survey.id },
  };
}

const requestHref = (requestId: string) => `/care/requests/view?id=${requestId}`;

export interface NotifiableRequest {
  id: string;
  schoolId: string;
  topic: string;
  urgency: string;
  createdAt: Date;
}

@Injectable()
export class CareNotifyService {
  private readonly logger = new Logger(CareNotifyService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
    private readonly childPush: SchoolChildPushService,
  ) {}

  /** Shoshilinch murojaat: mas'ul psixolog va o'rinbosarga saqlangan bildirishnoma (sozlangan bo'lsa). */
  async urgentCreated(tx: Tx, request: NotifiableRequest, staffIds: readonly string[], className: string): Promise<void> {
    const targets = [...new Set(staffIds)];
    if (targets.length === 0) return;
    const id = urgentNotificationId(request.id);
    const data = {
      schoolId: request.schoolId,
      kind: 'CARE_URGENT',
      at: request.createdAt,
      roles: ['PSYCHOLOGIST'],
      classIds: [],
      staffIds: targets,
      params: { className },
      subject: this.topicLabel(request.topic),
      href: requestHref(request.id),
    };
    await tx.schoolStaffNotification.upsert({ where: { id }, create: { id, ...data }, update: data });
  }

  /**
   * Muddatida ochilmagan murojaat o'rinbosarga o'tdi: o'rinbosarga (nishonlangan) bildirishnoma;
   * shoshilinch bo'lsa direktorga ham — ism, sinf va havolasiz xavfsizlik signali.
   */
  async escalated(tx: Tx, request: NotifiableRequest, deputyStaffId: string, className: string, now: Date): Promise<void> {
    const toDeputy = {
      schoolId: request.schoolId,
      kind: request.urgency === 'URGENT' ? 'CARE_URGENT' : 'CARE_NEW',
      at: now,
      roles: ['PSYCHOLOGIST'],
      classIds: [],
      staffIds: [deputyStaffId],
      params: { className },
      subject: ESCALATED_SUBJECT,
      href: requestHref(request.id),
    };
    const deputyId = escalationNotificationId(request.id);
    await tx.schoolStaffNotification.upsert({ where: { id: deputyId }, create: { id: deputyId, ...toDeputy }, update: toDeputy });
    if (request.urgency !== 'URGENT') return;
    const toDirector = { schoolId: request.schoolId, kind: 'SAFETY_SIGNAL', at: now, roles: ['DIRECTOR'], classIds: [], staffIds: [], params: {}, href: null };
    const directorId = directorNotificationId(request.id);
    await tx.schoolStaffNotification.upsert({ where: { id: directorId }, create: { id: directorId, ...toDirector }, update: toDirector });
  }

  /** Murojaat `NEW` holatdan chiqdi — unga bog'liq saqlangan bildirishnomalar endi kerak emas. */
  async clearFor(tx: Tx, requestId: string): Promise<void> {
    await tx.schoolStaffNotification.deleteMany({ where: { id: { in: careNotificationIds(requestId) } } });
  }

  /**
   * Xodim javobi haqida bolaga NEYTRAL push. Bolada token yo'q — jim o'tkazib yuboriladi (faqat log);
   * FCM xatosi hech qachon chaqiruvchini yiqitmaydi. Logda foydalanuvchi / murojaat id'si yo'q.
   */
  async notifyChildOfReply(childUserId: string | null, requestId: string): Promise<void> {
    if (!childUserId) return;
    try {
      if ((await this.prisma.fcmToken.count({ where: { userId: childUserId } })) === 0) {
        this.logger.log('bola xabari push o\'tkazib yuborildi: qurilma tokeni yo\'q');
        return;
      }
      const lang = await this.fcm.getUserLang(childUserId);
      const result = await this.fcm.sendPushToUser(childUserId, {
        title: tr(lang, 'careMessage.title'),
        body: tr(lang, 'careMessage.body'),
        data: { type: CARE_MESSAGE_PUSH_TYPE, requestId },
      });
      if (result.sent === 0) this.logger.log('bola xabari push yetkazilmadi (FCM qabul qilmadi)');
    } catch (err) {
      this.logger.warn(`bola xabari push xatosi: ${err instanceof Error ? err.message : 'noma\'lum'}`);
    }
  }

  /**
   * So'rovnoma faollashdi: [classIds] (so'rovnoma yosh guruhlari sinflari) dagi, ilovasi ulangan bolalarga
   * NEYTRAL push — har bola uchun bir marta. Qaytadi: FCM qabul qilganlar soni; xato yutiladi (log).
   */
  async surveyActivated(schoolId: string, surveyId: string, classIds: readonly string[]): Promise<number> {
    if (classIds.length === 0) return 0;
    try {
      const rows = await this.prisma.schoolStudent.findMany({
        where: { ...enrolledChildWhere(schoolId), classId: { in: [...classIds] } },
        select: { childId: true, child: { select: { childUserId: true } } },
      });
      return await this.childPush.sendOnce(toRecipients(rows), CARE_SURVEY_DEDUPE_KIND, surveyId, (lang) =>
        careSurveyPush(lang, { id: surveyId }),
      );
    } catch (err) {
      this.logger.warn(`so'rovnoma push xatosi: ${errorLabel(err)}`);
      return 0;
    }
  }

  private topicLabel(topic: string) {
    return CARE_TOPIC_LABELS[topic] ?? CARE_TOPIC_LABELS.OTHER!;
  }
}
