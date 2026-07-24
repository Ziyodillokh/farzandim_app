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
import { MailService } from '../../common/mail/mail.service';
import { AuditService } from '../../common/audit/audit.service';
import { BUCKETS, BucketName } from '../../common/storage/storage.constants';
import {
  hashPassword,
  verifyPassword,
} from '../../admin/admin-auth/helpers/password';
import { UpdateUserDto } from './dto/update-user.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyPhoneDto } from './dto/verify-phone.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { RequestEmailOtpDto } from './dto/request-email-otp.dto';
import { VerifyEmailDto } from './dto/verify-email.dto';
import { randomInt } from 'crypto';
import admin from 'firebase-admin';

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
    private readonly mail: MailService,
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
        email: true,
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

    // Media (MinIO) kalitlarini DB o'chirishdan OLDIN yig'amiz — cascade delete
    // yozuvlarni yo'qotgach kalitlar topilmasdi. Keyin baytlarni o'chiramiz.
    const media = await this.collectUserMediaKeys(userId);

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

    // MinIO obyektlarini o'chiramiz (best-effort — DB o'chirildi; bu ortiqcha
    // baytlarni tozalaydi. account-deletion.html "fayllar ham olib tashlanadi"
    // va'dasini bajaradi. Xato akkaunt o'chirishni buzmaydi).
    await this.deleteMediaObjects(media);

    // Firestore'dagi bola PII (telefon raqami / XP / bildirishnomalar) —
    // `users/{userId}` shoxi (recursiveDelete: hujjat + barcha subkolleksiyalar,
    // shu jumladan `children/{childId}`). parentUid == parent Postgres user id.
    // Best-effort — xato akkaunt o'chirishni buzmaydi (Postgres/MinIO o'chdi).
    await this.deleteFirestoreData(userId);

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

  /**
   * Foydalanuvchi (+ uning bolalari) barcha MinIO media kalitlarini yig'adi:
   * avatarlar, ovozli/video xabarlar, chat media, foto so'rovlari. `deleteAccount`
   * DB o'chirishdan OLDIN chaqiradi (keyin yozuvlar yo'qoladi).
   */
  private async collectUserMediaKeys(
    userId: string,
  ): Promise<Array<{ bucket: BucketName; key: string }>> {
    const objects: Array<{ bucket: BucketName; key: string }> = [];
    const push = (bucket: BucketName, key: string | null | undefined) => {
      // http URL = tashqi (Telegram/Google avatar) — MinIO'da emas, o'tkazamiz.
      if (key && !key.startsWith('http')) objects.push({ bucket, key });
    };

    const children = await this.prisma.child.findMany({
      where: { parentId: userId },
      select: { id: true, childUserId: true, photoPath: true },
    });
    const childIds = children.map((c) => c.id);
    const childUserIds = children
      .map((c) => c.childUserId)
      .filter((v): v is string => Boolean(v));
    const allUserIds = [userId, ...childUserIds];

    // Avatarlar (parent + bola user profillari + bola rasmlari + photo-request).
    const users = await this.prisma.user.findMany({
      where: { id: { in: allUserIds } },
      select: { avatarUrl: true },
    });
    for (const u of users) push(BUCKETS.avatars, u.avatarUrl);
    for (const c of children) push(BUCKETS.avatars, c.photoPath);

    // Ovozli xabarlar (storagePath) + chat media (mediaKey).
    const voice = await this.prisma.voiceMessage.findMany({
      where: {
        OR: [
          { senderId: { in: allUserIds } },
          { receiverId: { in: allUserIds } },
        ],
      },
      select: { storagePath: true, mediaKey: true },
    });
    for (const v of voice) {
      push(BUCKETS.voice, v.storagePath);
      push(BUCKETS.chat, v.mediaKey);
    }

    // Video xabarlar (storagePath + thumbnail).
    const video = await this.prisma.videoMessage.findMany({
      where: {
        OR: [
          { senderId: { in: allUserIds } },
          { receiverId: { in: allUserIds } },
        ],
      },
      select: { storagePath: true, thumbnailPath: true },
    });
    for (const v of video) {
      push(BUCKETS.video, v.storagePath);
      push(BUCKETS.video, v.thumbnailPath);
    }

    // Foto so'rovlari (avatars bucket'da — photo-requests.service).
    const photos = await this.prisma.photoRequest.findMany({
      where: {
        OR: [{ parentId: userId }, { childId: { in: childIds } }],
      },
      select: { photoPath: true, thumbnailPath: true },
    });
    for (const p of photos) {
      push(BUCKETS.avatars, p.photoPath);
      push(BUCKETS.avatars, p.thumbnailPath);
    }

    return objects;
  }

  /** MinIO obyektlarini best-effort o'chiradi (bittasi yiqilsa boshqalari davom). */
  private async deleteMediaObjects(
    objects: Array<{ bucket: BucketName; key: string }>,
  ): Promise<void> {
    if (objects.length === 0) return;
    const results = await Promise.allSettled(
      objects.map((o) => this.storage.delete(o.bucket, o.key)),
    );
    const failed = results.filter((r) => r.status === 'rejected').length;
    this.logger.log(
      `deleteAccount media: ${objects.length - failed}/${objects.length} ` +
        "obyekt o'chirildi",
    );
  }

  /**
   * Firestore'dagi `users/{parentUserId}` hujjatini + barcha subkolleksiyalarini
   * (`children/{childId}` — telefon raqami/XP/notif) recursiv o'chiradi.
   * firebase-admin FcmService tomonidan init qilinadi. Best-effort.
   */
  private async deleteFirestoreData(parentUserId: string): Promise<void> {
    try {
      // Init qilinmagan bo'lsa (credential yo'q/dev) — jimgina o'tkazamiz.
      if (admin.apps.length === 0) return;
      const db = admin.firestore();
      await db.recursiveDelete(db.collection('users').doc(parentUserId));
      this.logger.log(`Firestore users/${parentUserId} o'chirildi`);
    } catch (err) {
      this.logger.warn(`Firestore o'chirish xatosi (${parentUserId}): ${err}`);
    }
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

    const code = this.genCode();

    // Eskiz tasdiqlangan REGISTER shabloni — boshqa matn yuborilsa Eskiz
    // "not in template" xato qaytaradi. Avval yuboramiz: yuborib bo'lmasa
    // OtpCode yozilmaydi (aks holda muvaffaqiyatsiz yuborish 60s cooldown'ni
    // ishga tushirib qayta urinishni bloklardi).
    const smsResult = await this.sms.sendRegisterCode(phone, code);
    if (!smsResult.sent) {
      this.logger.error({ phone, err: smsResult.error }, 'OTP SMS yuborilmadi');
      throw new BadGatewayException("SMS yuborib bo'lmadi");
    }

    await this.prisma.otpCode.create({
      data: {
        phone,
        code,
        expiresAt: new Date(Date.now() + OTP_TTL_MS),
      },
    });

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

    // Pre-check bilan update orasidagi poyga: @unique buzilsa (P2002) toza
    // 409 qaytaramiz (500 emas).
    try {
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
    } catch (err) {
      if ((err as { code?: string })?.code === 'P2002') {
        throw new ConflictException('Phone already in use');
      }
      throw err;
    }

    return { id: userId, phone, isPhoneVerified: true };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /users/me/password — eski parol bilan o'zgartirish            */
  /* ------------------------------------------------------------------ */

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { passwordHash: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    // Faqat social-login (Telegram/Google/Apple) bo'lsa parol yo'q — tiklash
    // orqali o'rnatilishi kerak (eski parol tekshirib bo'lmaydi).
    if (!user.passwordHash) {
      throw new BadRequestException(
        "Parol o'rnatilmagan. Parolni tiklash orqali o'rnating.",
      );
    }
    const valid = await verifyPassword(dto.oldPassword, user.passwordHash);
    if (!valid) {
      throw new BadRequestException("Eski parol noto'g'ri");
    }
    if (dto.newPassword === dto.oldPassword) {
      throw new BadRequestException('Yangi parol eskisidan farq qilishi kerak');
    }
    const passwordHash = await hashPassword(dto.newPassword);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
    });
    return { ok: true };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /users/me/password/request-otp — joriy telefonga OTP          */
  /* ------------------------------------------------------------------ */

  async requestPasswordOtp(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true },
    });
    if (!user?.phone) {
      throw new BadRequestException(
        "Telefon raqami yo'q — parolni telefon orqali tiklab bo'lmaydi",
      );
    }
    if (!this.sms.isSmsConfigured()) {
      throw new ServiceUnavailableException('SMS xizmati hozircha mavjud emas');
    }
    const recent = await this.prisma.otpCode.findFirst({
      where: {
        phone: user.phone,
        createdAt: { gt: new Date(Date.now() - OTP_RESEND_COOLDOWN_MS) },
      },
    });
    if (recent) {
      throw new BadRequestException('Kod yaqinda yuborildi. Biroz kuting.');
    }
    const code = this.genCode();
    // Avval yuboramiz: yuborib bo'lmasa OtpCode yozilmaydi (aks holda cooldown
    // haqiqiy qayta urinishni bloklardi).
    const smsResult = await this.sms.sendRegisterCode(user.phone, code);
    if (!smsResult.sent) {
      this.logger.error(
        { phone: user.phone, err: smsResult.error },
        'Parol reset OTP SMS yuborilmadi',
      );
      throw new BadGatewayException("SMS yuborib bo'lmadi");
    }
    await this.prisma.otpCode.create({
      data: {
        phone: user.phone,
        code,
        expiresAt: new Date(Date.now() + OTP_TTL_MS),
      },
    });
    return { ok: true, message: 'Tasdiqlash kodi yuborildi' };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /users/me/password/reset — OTP tasdiqlab yangi parol          */
  /* ------------------------------------------------------------------ */

  async resetPasswordWithOtp(userId: string, dto: ResetPasswordDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true },
    });
    if (!user?.phone) {
      throw new BadRequestException(
        "Telefon raqami yo'q — parolni telefon orqali tiklab bo'lmaydi",
      );
    }
    const otp = await this.prisma.otpCode.findFirst({
      where: {
        phone: user.phone,
        verifiedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) {
      throw new BadRequestException('Kod topilmadi yoki muddati tugagan');
    }
    if (otp.attempts >= OTP_MAX_ATTEMPTS) {
      throw new BadRequestException("Juda ko'p urinish. Yangi kod so'rang.");
    }
    if (otp.code !== dto.code) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException("Noto'g'ri kod");
    }
    const passwordHash = await hashPassword(dto.newPassword);
    await this.prisma.$transaction([
      this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { verifiedAt: new Date() },
      }),
      this.prisma.user.update({
        where: { id: userId },
        data: { passwordHash },
      }),
    ]);
    return { ok: true };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /users/me/email — yangi emailga OTP                           */
  /* ------------------------------------------------------------------ */

  async requestEmailOtp(userId: string, dto: RequestEmailOtpDto) {
    const email = dto.email.trim().toLowerCase();
    if (!this.mail.isMailConfigured()) {
      throw new ServiceUnavailableException(
        'Email xizmati hozircha mavjud emas',
      );
    }
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing && existing.id !== userId) {
      throw new ConflictException('Email already in use');
    }
    const recent = await this.prisma.otpCode.findFirst({
      where: {
        email,
        createdAt: { gt: new Date(Date.now() - OTP_RESEND_COOLDOWN_MS) },
      },
    });
    if (recent) {
      throw new BadRequestException('Kod yaqinda yuborildi. Biroz kuting.');
    }
    const code = this.genCode();
    // Avval yuboramiz: yuborib bo'lmasa OtpCode yozilmaydi.
    const mailResult = await this.mail.sendVerifyCode(email, code);
    if (!mailResult.sent) {
      this.logger.error(
        { email, err: mailResult.error },
        'Email OTP yuborilmadi',
      );
      throw new BadGatewayException("Email yuborib bo'lmadi");
    }
    await this.prisma.otpCode.create({
      data: {
        email,
        code,
        expiresAt: new Date(Date.now() + OTP_TTL_MS),
      },
    });
    return { ok: true, message: 'Tasdiqlash kodi yuborildi' };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /users/me/email/verify — OTP tasdiqlab emailni saqlash        */
  /* ------------------------------------------------------------------ */

  async verifyEmailOtp(userId: string, dto: VerifyEmailDto) {
    const email = dto.email.trim().toLowerCase();
    const otp = await this.prisma.otpCode.findFirst({
      where: {
        email,
        verifiedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) {
      throw new BadRequestException('Kod topilmadi yoki muddati tugagan');
    }
    if (otp.attempts >= OTP_MAX_ATTEMPTS) {
      throw new BadRequestException("Juda ko'p urinish. Yangi kod so'rang.");
    }
    if (otp.code !== dto.code) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException("Noto'g'ri kod");
    }
    // Race-condition: tasdiqlash payti email band bo'lib qolmaganini tekshir.
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing && existing.id !== userId) {
      throw new ConflictException('Email already in use');
    }
    // Pre-check bilan update orasidagi poyga: @unique buzilsa (P2002) toza
    // 409 qaytaramiz (500 emas).
    try {
      await this.prisma.$transaction([
        this.prisma.otpCode.update({
          where: { id: otp.id },
          data: { verifiedAt: new Date() },
        }),
        this.prisma.user.update({
          where: { id: userId },
          data: { email },
        }),
      ]);
    } catch (err) {
      if ((err as { code?: string })?.code === 'P2002') {
        throw new ConflictException('Email already in use');
      }
      throw err;
    }
    return { id: userId, email, isEmailVerified: true };
  }

  /** 6 xonali OTP kod — crypto.randomInt (bashorat qilib bo'lmaydigan). */
  private genCode(): string {
    return String(randomInt(100_000, 1_000_000));
  }
}
