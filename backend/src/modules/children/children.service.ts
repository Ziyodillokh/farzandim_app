import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  InternalServerErrorException,
  UnsupportedMediaTypeException,
  PayloadTooLargeException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { AuditService } from '../../common/audit/audit.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { BUCKETS } from '../../common/storage/storage.constants';
import { CreateChildDto } from './dto/create-child.dto';
import { UpdateChildDto } from './dto/update-child.dto';
import { UpdateDeviceInfoDto } from './dto/update-device-info.dto';
import { UpdateInterestsDto } from './dto/update-interests.dto';

const ALLOWED_AVATAR_MIMES = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
];
const MAX_AVATAR_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB
const MAX_CHILDREN_PER_PARENT = 3; // Bir ota-ona maksimal 3 ta farzand

@Injectable()
export class ChildrenService {
  private readonly logger = new Logger(ChildrenService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly audit: AuditService,
    private readonly fcm: FcmService,
  ) {}

  /* ------------------------------------------------------------------ */
  /*  Family code — 5 digits (10000-99999), easy to remember             */
  /* ------------------------------------------------------------------ */

  private generateFamilyCode(): string {
    return Math.floor(10_000 + Math.random() * 90_000).toString();
  }

  private async generateUniqueFamilyCode(): Promise<string> {
    for (let i = 0; i < 10; i++) {
      const code = this.generateFamilyCode();
      const existing = await this.prisma.child.findUnique({
        where: { familyCode: code },
      });
      if (!existing) return code;
    }
    throw new InternalServerErrorException(
      'Could not generate unique family code',
    );
  }

  /* ------------------------------------------------------------------ */
  /*  GET /children                                                      */
  /* ------------------------------------------------------------------ */

  async findAll(parentId: string) {
    const children = await this.prisma.child.findMany({
      where: { parentId },
      orderBy: { createdAt: 'desc' },
    });
    return { children };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /children                                                     */
  /* ------------------------------------------------------------------ */

  async create(
    parentId: string,
    dto: CreateChildDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    // Maksimal 3 ta farzand cheklovi.
    const existingCount = await this.prisma.child.count({ where: { parentId } });
    if (existingCount >= MAX_CHILDREN_PER_PARENT) {
      throw new BadRequestException(
        `Maksimal ${MAX_CHILDREN_PER_PARENT} ta farzand qo'shish mumkin`,
      );
    }

    const familyCode = await this.generateUniqueFamilyCode();

    const child = await this.prisma.child.create({
      data: {
        parentId,
        ...dto,
        familyCode,
      },
    });

    await this.audit.log(parentId, 'child', 'CREATE', child.id, dto, reqMeta);

    return child;
  }

  /* ------------------------------------------------------------------ */
  /*  GET /children/:id                                                  */
  /* ------------------------------------------------------------------ */

  async findOne(id: string, userId: string) {
    const child = await this.prisma.child.findUnique({ where: { id } });

    if (!child) {
      throw new NotFoundException('Child not found');
    }

    // Only parent or child's own user can view
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    return child;
  }

  /**
   * Qurilma siyosati — `blockUnknownSources`. Ota-ona (toggle uchun) yoki
   * bola (enforce uchun) o'qiy oladi (yengil javob, egalik tekshiriladi).
   */
  async getDevicePolicy(id: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id },
      select: {
        parentId: true,
        childUserId: true,
        blockUnknownSources: true,
      },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    return { blockUnknownSources: child.blockUnknownSources };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /children/:id/device-info — qurilma heartbeat (GPS'siz)        */
  /* ------------------------------------------------------------------ */

  /**
   * Bola qurilmasi heartbeat'i — model/batareya/wifi + lastSeenAt yangilaydi.
   * GPS talab qilmaydi (Child App davriy yuboradi). Shu orqali ota-ona
   * real qurilma ma'lumotini va online holatni ko'radi.
   */
  async updateDeviceInfo(
    id: string,
    userId: string,
    dto: UpdateDeviceInfoDto,
  ) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    // Faqat bola qurilmasi (childUserId) yoki ota-ona yangilashi mumkin.
    if (child.childUserId !== userId && child.parentId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const data: Record<string, unknown> = { lastSeenAt: new Date() };
    if (dto.batteryLevel !== undefined) data.batteryLevel = dto.batteryLevel;
    if (dto.isCharging !== undefined) data.isCharging = dto.isCharging;
    if (dto.deviceModel !== undefined) data.deviceModel = dto.deviceModel;
    if (dto.androidVersion !== undefined) {
      data.androidVersion = dto.androidVersion;
    }
    if (dto.appVersion !== undefined) data.appVersion = dto.appVersion;
    if (dto.wifiName !== undefined) data.wifiName = dto.wifiName;
    // Heartbeat kelgani — qurilma ulangan deb belgilaymiz.
    if (!child.isConnected) data.isConnected = true;

    await this.prisma.child.update({ where: { id }, data });
    return { ok: true };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /children/:id/ring — bola qurilmasini baland jiringlat         */
  /* ------------------------------------------------------------------ */

  /**
   * Ota-ona bola qurilmasini baland ovozda jiringlatadi (qurilmani topish).
   * Sof DATA FCM push yuboriladi (`type:'ring'`) — bola ilovasi fonda/yopiq
   * bo'lsa ham native RingService ishga tushadi va STREAM_ALARM'da
   * jiringlaydi (silent rejimda ham).
   */
  async ring(
    id: string,
    userId: string,
    reqMeta?: {
      ip?: string;
      headers?: Record<string, string | string[] | undefined>;
    },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can ring');
    }
    if (!child.childUserId) {
      throw new BadRequestException('Child device not paired');
    }

    const result = await this.fcm.sendPushToUser(child.childUserId, {
      title: 'Farzandim',
      body: 'Qurilma chaqirilmoqda',
      data: {
        type: 'ring',
        action: 'start',
        durationMs: '30000',
        childId: id,
      },
      dataOnly: true,
    });

    await this.audit.log(
      userId,
      'child',
      'RING',
      id,
      { sent: result.sent },
      reqMeta,
    );

    return { ok: true, sent: result.sent };
  }

  /* ------------------------------------------------------------------ */
  /*  PUT /children/:id                                                  */
  /* ------------------------------------------------------------------ */

  async update(
    id: string,
    userId: string,
    dto: UpdateChildDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can update');
    }

    const updated = await this.prisma.child.update({
      where: { id },
      data: dto,
    });

    await this.audit.log(userId, 'child', 'UPDATE', id, dto, reqMeta);

    return updated;
  }

  /* ------------------------------------------------------------------ */
  /*  PUT /children/me/interests — bola onboarding'da tanlagan tag'lar    */
  /* ------------------------------------------------------------------ */

  /**
   * Bola onboarding ekranida tanlagan qiziqishlarni saqlaydi (PATCH-like
   * semantika — to'liq array'ni almashtiradi). `userId` joriy bola User
   * `id`'si (CHILD JWT) — undan `childUserId` orqali Child topiladi.
   *
   * Tavsiya tizimi shu yerdan o'qiydi (Books/Videos/Audiobooks/Contests
   * feed'lari `interests` overlap orqali sort/filter qiladi).
   */
  async updateMyInterests(
    userId: string,
    dto: UpdateInterestsDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findFirst({
      where: { childUserId: userId },
      select: { id: true },
    });
    if (!child) {
      throw new NotFoundException('Bola yozuvi topilmadi');
    }

    // Tag'larni normalize: trim + lowercase + bo'sh'larni olib tashlash.
    const normalized = Array.from(
      new Set(
        dto.interests
          .map((t) => t.trim().toLowerCase())
          .filter((t) => t.length > 0),
      ),
    );

    // Prisma client `interests` String[]'ni avtomatik tanigach `as any` olib
    // tashlanadi. Migratsiya `20260611150000_add_child_interests` ko'chiriladi
    // → `prisma generate` ishga tushadi → type to'g'rilanadi.
    const updated = await this.prisma.child.update({
      where: { id: child.id },
      data: { interests: normalized } as any,
      select: { id: true, interests: true } as any,
    });

    await this.audit.log(
      userId,
      'child',
      'UPDATE',
      child.id,
      { interests: normalized },
      reqMeta,
    );

    return updated;
  }

  /* ------------------------------------------------------------------ */
  /*  DELETE /children/:id                                               */
  /* ------------------------------------------------------------------ */

  async remove(
    id: string,
    userId: string,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can delete');
    }

    await this.prisma.child.delete({ where: { id } });
    await this.audit.log(userId, 'child', 'DELETE', id, undefined, reqMeta);

    return { ok: true };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /children/:id/pair-code — regenerate family code              */
  /* ------------------------------------------------------------------ */

  async regeneratePairCode(
    id: string,
    userId: string,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can regenerate');
    }

    const familyCode = await this.generateUniqueFamilyCode();
    const oldChildUserId = child.childUserId;

    const updated = await this.prisma.$transaction(async (tx) => {
      const c = await tx.child.update({
        where: { id },
        data: {
          familyCode,
          isConnected: false,
          childUserId: null,
          pairedAt: null,
        },
      });

      if (oldChildUserId) {
        await tx.user.update({
          where: { id: oldChildUserId },
          data: { isActive: false },
        });
        // Clean up FCM tokens — old device should not receive pushes
        await tx.fcmToken.deleteMany({ where: { userId: oldChildUserId } });
      }

      return c;
    });

    await this.audit.log(
      userId,
      'child',
      'UPDATE',
      id,
      { action: 'PAIR_CODE_REGENERATE', previousChildUserId: oldChildUserId },
      reqMeta,
    );

    return { familyCode: updated.familyCode };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /children/:id/avatar — multipart upload                       */
  /* ------------------------------------------------------------------ */

  async uploadAvatar(
    id: string,
    userId: string,
    file: { buffer: Buffer; mimetype: string; originalname: string },
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can update avatar');
    }

    if (!ALLOWED_AVATAR_MIMES.includes(file.mimetype)) {
      throw new UnsupportedMediaTypeException('Unsupported image format');
    }

    if (file.buffer.length > MAX_AVATAR_SIZE_BYTES) {
      throw new PayloadTooLargeException('File too large (max 5 MB)');
    }

    const ext = file.originalname.split('.').pop() || 'jpg';
    const storagePath = `child-avatars/${id}.${ext}`;

    await this.storage.upload(BUCKETS.avatars, storagePath, file.buffer, file.mimetype);

    // Delete old avatar if path differs
    if (child.photoPath && child.photoPath !== storagePath) {
      try {
        await this.storage.delete(BUCKETS.avatars, child.photoPath);
      } catch (err) {
        this.logger.warn({ err }, 'Old avatar delete failed');
      }
    }

    const updated = await this.prisma.child.update({
      where: { id },
      data: { photoPath: storagePath },
    });

    await this.audit.log(
      userId,
      'child',
      'UPLOAD',
      id,
      { field: 'avatar', storagePath },
      reqMeta,
    );

    return updated;
  }

  /* ------------------------------------------------------------------ */
  /*  GET /children/:id/avatar — signed URL (1 hour)                     */
  /* ------------------------------------------------------------------ */

  async getAvatarUrl(id: string, userId: string) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    if (!child.photoPath) {
      throw new NotFoundException('No avatar uploaded');
    }

    const url = await this.storage.getSignedUrl(BUCKETS.avatars, child.photoPath, 3600);
    return { url, expiresIn: 3600 };
  }

  /** Avatar baytlarini proxy uchun qaytaradi (auth'siz, childId UUID orqali). */
  async getAvatarObject(id: string) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child?.photoPath) {
      throw new NotFoundException('No avatar uploaded');
    }
    try {
      return await this.storage.getObject(BUCKETS.avatars, child.photoPath);
    } catch {
      // Obyekt MinIO'da yo'q (o'chirilgan/ko'chirilmagan) — 500 emas, 404.
      throw new NotFoundException('Avatar object not found');
    }
  }

  /* ------------------------------------------------------------------ */
  /*  DELETE /children/:id/avatar                                        */
  /* ------------------------------------------------------------------ */

  async deleteAvatar(
    id: string,
    userId: string,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id } });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can delete avatar');
    }
    if (!child.photoPath) {
      return { ok: true };
    }

    try {
      await this.storage.delete(BUCKETS.avatars, child.photoPath);
    } catch (err) {
      this.logger.warn({ err }, 'Avatar delete failed, clearing DB anyway');
    }

    await this.prisma.child.update({
      where: { id },
      data: { photoPath: null },
    });

    await this.audit.log(
      userId,
      'child',
      'DELETE',
      id,
      { field: 'avatar' },
      reqMeta,
    );

    return { ok: true };
  }
}
