import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  Logger,
  ServiceUnavailableException,
  BadGatewayException,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { SmsService } from '../../common/sms/sms.service';
import { AuditService } from '../../common/audit/audit.service';
import { BUCKETS } from '../../common/storage/storage.constants';
import { UpdateUserDto } from './dto/update-user.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyPhoneDto } from './dto/verify-phone.dto';

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const OTP_RESEND_COOLDOWN_MS = 60 * 1000; // 60 seconds
const OTP_MAX_ATTEMPTS = 5;

const ALLOWED_AVATAR_MIMES = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
];
const MAX_AVATAR_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB
const AVATAR_URL_TTL = 6 * 24 * 60 * 60; // 6 days (signed URL)

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly sms: SmsService,
    private readonly audit: AuditService,
  ) {}

  /* ------------------------------------------------------------------ */
  /*  Avatar URL resolver                                                */
  /* ------------------------------------------------------------------ */

  private async resolveAvatarUrl(stored: string | null): Promise<string | null> {
    if (!stored) return null;
    if (stored.startsWith('http')) return stored;
    try {
      return await this.storage.getSignedUrl(BUCKETS.avatars, stored, AVATAR_URL_TTL);
    } catch {
      return null;
    }
  }

  /* ------------------------------------------------------------------ */
  /*  GET /users/me                                                      */
  /* ------------------------------------------------------------------ */

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        phone: true,
        role: true,
        name: true,
        avatarUrl: true,
        telegramId: true,
        language: true,
        isActive: true,
        createdAt: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const isPhoneVerified =
      user.phone !== null && !user.phone.startsWith('tg:');

    return {
      ...user,
      avatarUrl: await this.resolveAvatarUrl(user.avatarUrl),
      phone: isPhoneVerified ? user.phone : null,
      isPhoneVerified,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  PUT /users/me                                                      */
  /* ------------------------------------------------------------------ */

  async updateProfile(userId: string, dto: UpdateUserDto) {
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: dto,
      select: {
        id: true,
        name: true,
        avatarUrl: true,
        language: true,
      },
    });

    return updated;
  }

  /* ------------------------------------------------------------------ */
  /*  DELETE /users/me                                                   */
  /* ------------------------------------------------------------------ */

  async deleteAccount(
    userId: string,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    await this.prisma.$transaction(async (tx) => {
      const children = await tx.child.findMany({
        where: { parentId: userId },
        select: { childUserId: true },
      });
      const childUserIds = children
        .map((c) => c.childUserId)
        .filter((id): id is string => Boolean(id));

      // Cascade: parent delete removes children + all related data
      await tx.user.delete({ where: { id: userId } });

      // Child User rows are not cascade-deleted, remove them explicitly
      if (childUserIds.length > 0) {
        await tx.user.deleteMany({ where: { id: { in: childUserIds } } });
      }
    });

    await this.audit.log(
      userId,
      'user',
      'DELETE',
      userId,
      { role: user.role, telegramId: user.telegramId },
      reqMeta,
    );

    return { ok: true, message: "Akkaunt o'chirildi" };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /users/me/avatar (multipart)                                  */
  /* ------------------------------------------------------------------ */

  async uploadAvatar(
    userId: string,
    file: { buffer: Buffer; mimetype: string; originalname: string },
  ) {
    if (!ALLOWED_AVATAR_MIMES.includes(file.mimetype)) {
      throw new UnsupportedMediaTypeException('Faqat JPEG/PNG/WebP rasm');
    }

    if (file.buffer.length > MAX_AVATAR_SIZE_BYTES) {
      throw new PayloadTooLargeException('Rasm 5 MB dan katta');
    }

    const ext =
      file.mimetype === 'image/png'
        ? 'png'
        : file.mimetype === 'image/webp'
          ? 'webp'
          : 'jpg';
    const key = `users/${userId}.${ext}`;

    await this.storage.upload(BUCKETS.avatars, key, file.buffer, file.mimetype);
    await this.prisma.user.update({
      where: { id: userId },
      data: { avatarUrl: key },
    });

    const avatarUrl = await this.storage.getSignedUrl(
      BUCKETS.avatars,
      key,
      AVATAR_URL_TTL,
    );

    return { ok: true, avatarUrl };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /users/me/phone — request OTP                                 */
  /* ------------------------------------------------------------------ */

  async requestPhoneOtp(userId: string, dto: RequestOtpDto) {
    const { phone } = dto;

    if (!this.sms.isSmsConfigured()) {
      throw new ServiceUnavailableException('SMS xizmati hozircha mavjud emas');
    }

    // Check if phone is already taken by another user
    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing && existing.id !== userId) {
      throw new ConflictException('Phone already in use');
    }

    // Anti-spam: 60-second cooldown
    const recent = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        createdAt: { gt: new Date(Date.now() - OTP_RESEND_COOLDOWN_MS) },
      },
    });
    if (recent) {
      throw new BadRequestException(
        'Kod yaqinda yuborildi. Biroz kuting.',
      );
    }

    const code = String(Math.floor(100_000 + Math.random() * 900_000));

    await this.prisma.otpCode.create({
      data: {
        phone,
        code,
        expiresAt: new Date(Date.now() + OTP_TTL_MS),
      },
    });

    const smsResult = await this.sms.sendSms(
      phone,
      `Farzandim — tasdiqlash kodingiz: ${code}`,
    );
    if (!smsResult.sent) {
      this.logger.error({ phone, err: smsResult.error }, 'OTP SMS yuborilmadi');
      throw new BadGatewayException("SMS yuborib bo'lmadi");
    }

    return { ok: true, message: 'Tasdiqlash kodi yuborildi' };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /users/me/phone/verify — verify OTP                          */
  /* ------------------------------------------------------------------ */

  async verifyPhoneOtp(userId: string, dto: VerifyPhoneDto) {
    const { phone, code } = dto;

    const otp = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        verifiedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      throw new BadRequestException('Kod topilmadi yoki muddati tugagan');
    }

    if (otp.attempts >= OTP_MAX_ATTEMPTS) {
      throw new BadRequestException(
        "Juda ko'p urinish. Yangi kod so'rang.",
      );
    }

    if (otp.code !== code) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException("Noto'g'ri kod");
    }

    // Race-condition check: verify phone not taken by another user
    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing && existing.id !== userId) {
      throw new ConflictException('Phone already in use');
    }

    await this.prisma.$transaction([
      this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { verifiedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: { phone },
      }),
    ]);

    return { id: userId, phone, isPhoneVerified: true };
  }
}
