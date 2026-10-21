import { Injectable, Logger } from '@nestjs/common';
import { NotificationType } from '@prisma/client';
import admin from 'firebase-admin';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { BUCKETS, BucketName } from '../../common/storage/storage.constants';
import { tr } from '../../common/i18n/notification-i18n';

export interface MediaObject {
  bucket: BucketName;
  key: string;
}

/** O'chiriladigan bola profili (Child yozuvi) — kerakli maydonlar. */
export interface PurgeableChild {
  id: string;
  parentId: string;
  name: string;
  childUserId: string | null;
  photoPath: string | null;
}

/**
 * Bola ma'lumotlarini o'chirish — ikki yo'l (App Store audit F15/F40):
 *
 *  1) `deleteChildAccount` — bola ilovada "Uzish va ma'lumotlarimni
 *     o'chirish" (DELETE /users/me, role=CHILD). Bola QURILMA akkaunti
 *     (User), xabarlari, rasmlari, Kelajak javoblari, sessiya/push token'lari o'chadi; ota-ona
 *     yaratgan bola PROFILI (Child) esa QOLADI va bo'shatiladi — xuddi shu
 *     oila kodi bilan qayta ulanish mumkin (reviewer demo kodi ham buzilmaydi).
 *     Ota-onaga push + bildirishnoma yuboriladi.
 *
 *  2) `purgeChildProfile` — ota-ona bola profilini o'chiradi (DELETE
 *     /children/:id). Profil bilan birga bola User'i va barcha media ham.
 *
 * DB o'zgarishi tranzaksiyada; MinIO/Firestore tozalash — keyin, best-effort
 * (xato o'chirishni buzmaydi, faqat log).
 */
@Injectable()
export class ChildDataPurgeService {
  private readonly logger = new Logger(ChildDataPurgeService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly fcm: FcmService,
    private readonly realtime: RealtimeGateway,
  ) {}

  /* ------------------------------------------------------------------ */
  /*  1) Bola o'zi akkauntini o'chiradi                                  */
  /* ------------------------------------------------------------------ */

  async deleteChildAccount(
    childUserId: string,
  ): Promise<{ childId: string | null; mediaObjects: number }> {
    const child = await this.prisma.child.findUnique({
      where: { childUserId },
      select: {
        id: true,
        parentId: true,
        name: true,
        childUserId: true,
        photoPath: true,
      },
    });
    const media = await this.collectChildMedia(
      childUserId,
      child?.id ?? null,
      child?.photoPath ?? null,
    );

    await this.prisma.$transaction(async (tx) => {
      if (child) {
        // Profil QOLADI (ota-onaniki) — faqat bola qurilmasidan bo'shatiladi.
        await tx.child.update({
          where: { id: child.id },
          data: {
            childUserId: null,
            isConnected: false,
            pairedAt: null,
            photoPath: null,
            connectionLostNotifiedAt: null,
          },
        });
        await tx.photoRequest.deleteMany({ where: { childId: child.id } });
        await tx.aiMessage.deleteMany({ where: { childId: child.id } });
        // Kelajak: bolaning o'z javoblari (farovonlik, ochiq matn) va natijalari —
        // javoblar sessiya bilan cascade o'chadi; keyingi qurilma ularni ko'rmaydi.
        await tx.kelajakSession.deleteMany({ where: { childId: child.id } });
      }
      await tx.supportMessage.deleteMany({ where: { userId: childUserId } });
      // Cascade: ovozli/video xabarlar, FCM token'lar, sessiyalar.
      await tx.user.delete({ where: { id: childUserId } });
    });

    await this.deleteMedia(media);
    if (child) {
      await this.deleteFirestoreChild(child.parentId, child.id);
      await this.notifyParentChildDisconnected(child);
    }
    return { childId: child?.id ?? null, mediaObjects: media.length };
  }

  /* ------------------------------------------------------------------ */
  /*  2) Ota-ona bola profilini o'chiradi                                */
  /* ------------------------------------------------------------------ */

  async purgeChildProfile(
    child: PurgeableChild,
  ): Promise<{ childUserDeleted: boolean; mediaObjects: number }> {
    const childUserId = child.childUserId;
    const media = await this.collectChildMedia(
      childUserId,
      child.id,
      child.photoPath,
    );

    await this.prisma.$transaction(async (tx) => {
      // Cascade: lokatsiya, jadval, foto so'rovlar, AI suhbat va h.k.
      await tx.child.delete({ where: { id: child.id } });
      if (childUserId) {
        await tx.supportMessage.deleteMany({ where: { userId: childUserId } });
        // Child.childUser — onDelete SetNull, ya'ni avval User QOLIB KETARDI.
        await tx.user.deleteMany({ where: { id: childUserId, role: 'CHILD' } });
      }
    });

    if (childUserId) {
      // Bola qurilmasi (WS tirik bo'lsa) darhol lokal "unpair" qiladi.
      this.realtime.emitToUser(childUserId, 'child:unpaired', {
        childId: child.id,
        reason: 'CHILD_PROFILE_DELETED',
        at: new Date().toISOString(),
      });
    }
    await this.deleteMedia(media);
    await this.deleteFirestoreChild(child.parentId, child.id);
    return { childUserDeleted: !!childUserId, mediaObjects: media.length };
  }

  /* ------------------------------------------------------------------ */
  /*  Yordamchilar                                                       */
  /* ------------------------------------------------------------------ */

  /**
   * Bola (User + profil) MinIO kalitlarini DB o'chirishdan OLDIN yig'adi:
   * profil rasmi, User avatari, ovozli/video/chat media, foto so'rovlari,
   * support biriktirmalari.
   */
  async collectChildMedia(
    childUserId: string | null,
    childId: string | null,
    photoPath: string | null,
  ): Promise<MediaObject[]> {
    const objects: MediaObject[] = [];
    const push = (bucket: BucketName, key: string | null | undefined) => {
      // http URL = tashqi manzil — MinIO'da emas.
      if (key && !key.startsWith('http')) objects.push({ bucket, key });
    };

    push(BUCKETS.avatars, photoPath);
    if (childId) {
      const photos = await this.prisma.photoRequest.findMany({
        where: { childId },
        select: { photoPath: true, thumbnailPath: true },
      });
      for (const p of photos) {
        push(BUCKETS.avatars, p.photoPath);
        push(BUCKETS.avatars, p.thumbnailPath);
      }
    }
    if (!childUserId) return objects;

    const user = await this.prisma.user.findUnique({
      where: { id: childUserId },
      select: { avatarUrl: true },
    });
    push(BUCKETS.avatars, user?.avatarUrl);

    const party = {
      OR: [{ senderId: childUserId }, { receiverId: childUserId }],
    };
    const voice = await this.prisma.voiceMessage.findMany({
      where: party,
      select: { storagePath: true, mediaKey: true },
    });
    for (const v of voice) {
      push(BUCKETS.voice, v.storagePath);
      push(BUCKETS.chat, v.mediaKey);
    }
    const video = await this.prisma.videoMessage.findMany({
      where: party,
      select: { storagePath: true, thumbnailPath: true },
    });
    for (const v of video) {
      push(BUCKETS.video, v.storagePath);
      push(BUCKETS.video, v.thumbnailPath);
    }
    const support = await this.prisma.supportMessage.findMany({
      where: { userId: childUserId },
      select: { attachmentKey: true },
    });
    for (const m of support) push(BUCKETS.support, m.attachmentKey);

    return objects;
  }

  /** MinIO obyektlarini best-effort o'chiradi (bittasi yiqilsa boshqalari davom). */
  private async deleteMedia(objects: MediaObject[]): Promise<void> {
    if (objects.length === 0) return;
    const results = await Promise.allSettled(
      objects.map((o) => this.storage.delete(o.bucket, o.key)),
    );
    const failed = results.filter((r) => r.status === 'rejected').length;
    this.logger.log(
      `child purge media: ${objects.length - failed}/${objects.length} ` +
        "obyekt o'chirildi",
    );
  }

  /** Firestore `users/{parentId}/children/{childId}` shoxi (eski bola ilovasi yozgan). */
  private async deleteFirestoreChild(
    parentId: string,
    childId: string,
  ): Promise<void> {
    try {
      if (admin.apps.length === 0) return;
      const db = admin.firestore();
      await db.recursiveDelete(
        db.collection('users').doc(parentId).collection('children').doc(childId),
      );
    } catch (err) {
      this.logger.warn(`Firestore bola shoxini o'chirish xatosi: ${String(err)}`);
    }
  }

  /** Ota-onaga: "bola qurilmani uzdi" — push + bildirishnoma yozuvi. */
  private async notifyParentChildDisconnected(child: {
    id: string;
    parentId: string;
    name: string;
  }): Promise<void> {
    try {
      const lang = await this.fcm.getUserLang(child.parentId);
      const title = tr(lang, 'childDisconnected.title', { name: child.name });
      const body = tr(lang, 'childDisconnected.body');
      await this.prisma.notification.create({
        data: {
          childId: child.id,
          type: NotificationType.SYSTEM,
          title,
          body,
          data: { type: 'child_disconnected' },
        },
      });
      await this.fcm.sendPushToUser(child.parentId, {
        title,
        body,
        data: {
          type: 'child_disconnected',
          childId: child.id,
          childName: child.name,
        },
      });
    } catch (err) {
      // Akkaunt allaqachon o'chirildi — xabar yuborilmasa ham davom etamiz.
      this.logger.warn(`child_disconnected xabari yuborilmadi: ${String(err)}`);
    }
  }
}
