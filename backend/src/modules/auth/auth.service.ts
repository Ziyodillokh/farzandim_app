import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  NotFoundException,
  BadRequestException,
  BadGatewayException,
  ServiceUnavailableException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { SmsService } from '../../common/sms/sms.service';
import { MailService } from '../../common/mail/mail.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { TrialService } from '../trial/trial.service';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { EnvConfig } from '../../common/config/env.schema';
import { TelegramService, TelegramAuthData } from './strategies/telegram.service';
import {
  SocialAuthService,
  VerifiedSocialUser,
} from './strategies/social-auth.service';
import { TelegramAuthDto } from './dto/telegram-auth.dto';
import { ChildPairDto } from './dto/child-pair.dto';
import { RegisterDto } from './dto/register.dto';
import {
  ForgotPasswordRequestDto,
  ForgotPasswordResetDto,
} from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import {
  hashPassword,
  verifyPassword,
} from '../../admin/admin-auth/helpers/password';
import { randomUUID } from 'crypto';
import { Cron } from '@nestjs/schedule';
import {
  ReqMeta,
  extractClientIp,
  resolveGeo,
} from '../../common/helpers/geo-ip';
import { tr } from '../../common/i18n/notification-i18n';

// Session access request (2-qurilma limit) — 15 daqiqa amal qiladi.
const SESSION_ACCESS_TTL_MS = 15 * 60 * 1000;

/** Qurilma ma'lumotlari (login DTO'laridan keladi). */
interface DeviceMeta {
  deviceModel?: string;
  platform?: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly audit: AuditService,
    private readonly fcm: FcmService,
    private readonly realtime: RealtimeGateway,
    private readonly telegramService: TelegramService,
    private readonly socialAuth: SocialAuthService,
    private readonly sms: SmsService,
    private readonly mail: MailService,
    private readonly trial: TrialService,
  ) {}

  /* ------------------------------------------------------------------ */
  /*  Register OTP (public — auth bo'lmasligi mumkin)                    */
  /* ------------------------------------------------------------------ */
  // Frontend ko'p bosqichli sign-up UI uchun: telefon → SMS kod →
  // (verify) → profil (parol, ism). users.service.ts:200 esa
  // allaqachon login bo'lgan user uchun telefonni biriktirish flow'i.

  private static readonly REGISTER_OTP_TTL_MS = 5 * 60 * 1000;
  private static readonly REGISTER_OTP_RESEND_COOLDOWN_MS = 60 * 1000;
  private static readonly REGISTER_OTP_MAX_ATTEMPTS = 5;

  /// Verify'dan keyin `verifiedAt` yozilgan kod necha vaqt ichida `register()`
  /// chaqiruvini ochib turishi mumkin. 10 daqiqa — foydalanuvchi parol terish
  /// + ism kiritish uchun yetarli, lekin keyin qayta SMS so'rab tasdiqlatadi.
  private static readonly REGISTER_OTP_VERIFIED_VALIDITY_MS = 10 * 60 * 1000;

  async sendRegisterOtp(
    phone: string,
  ): Promise<{ ok: true; devCode?: string }> {
    if (!this.sms.isSmsConfigured()) {
      throw new ServiceUnavailableException('SMS xizmati hozircha mavjud emas');
    }

    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing) {
      throw new ConflictException("Bu telefon raqami allaqachon ro'yxatdan o'tgan");
    }

    const recent = await this.prisma.otpCode.findFirst({
      where: {
        phone,
        createdAt: {
          gt: new Date(Date.now() - AuthService.REGISTER_OTP_RESEND_COOLDOWN_MS),
        },
      },
    });
    if (recent) {
      throw new BadRequestException('Kod yaqinda yuborildi. Biroz kuting.');
    }

    const code = String(Math.floor(10_000 + Math.random() * 90_000));

    await this.prisma.otpCode.create({
      data: {
        phone,
        code,
        expiresAt: new Date(Date.now() + AuthService.REGISTER_OTP_TTL_MS),
      },
    });

    const smsResult = await this.sms.sendRegisterCode(phone, code);
    if (!smsResult.sent) {
      this.logger.error(
        { phone, err: smsResult.error },
        'Register OTP SMS yuborilmadi',
      );
      // DEV bypass: SMS ketmaganda (masalan Eskiz TEST rejimida "Number is
      // forbidden") `OTP_DEV_LOG=true` bo'lsa — kodni backend LOGiga chiqarib,
      // davom etamiz. Shunda test/dev'da real SMS'siz ro'yxatdan o'tish mumkin.
      // Prod'da bu flag o'rnatilmaydi → odatdagidek xato qaytadi.
      if (process.env.OTP_DEV_LOG === 'true') {
        this.logger.warn(
          `🔑 [DEV OTP] ${phone} -> ${code}  (SMS ketmadi: ${smsResult.error})`,
        );
        // Dev'da kodni javobда ham qaytaramiz (test qulay bo'lsin). Prod'da
        // flag yo'q → bu yerga yetib kelmaydi.
        return { ok: true, devCode: code };
      }
      throw new BadGatewayException("SMS yuborib bo'lmadi");
    }

    return { ok: true };
  }

  async verifyRegisterOtp(
    phone: string,
    code: string,
  ): Promise<{ ok: true }> {
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
    if (otp.attempts >= AuthService.REGISTER_OTP_MAX_ATTEMPTS) {
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

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { verifiedAt: new Date() },
    });

    return { ok: true };
  }

  /* ------------------------------------------------------------------ */
  /*  Register OTP — EMAIL varianti (SMS OTP bilan bir xil)              */
  /* ------------------------------------------------------------------ */
  // Telefon SMS OTP'ning aynan nusxasi, faqat OtpCode `email` ustuni +
  // MailService (nodemailer) orqali. Frontend: email → kod → (verify) →
  // /register (email + parol). register() email uchun ham verifiedAt
  // tekshiradi (chetlab o'tib bo'lmaydi).

  async sendRegisterEmailOtp(emailRaw: string): Promise<{ ok: true }> {
    const email = emailRaw.trim().toLowerCase();

    if (!this.mail.isMailConfigured()) {
      throw new ServiceUnavailableException(
        'Email xizmati hozircha mavjud emas',
      );
    }

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ConflictException("Bu email allaqachon ro'yxatdan o'tgan");
    }

    const recent = await this.prisma.otpCode.findFirst({
      where: {
        email,
        createdAt: {
          gt: new Date(Date.now() - AuthService.REGISTER_OTP_RESEND_COOLDOWN_MS),
        },
      },
    });
    if (recent) {
      throw new BadRequestException('Kod yaqinda yuborildi. Biroz kuting.');
    }

    const code = String(Math.floor(10_000 + Math.random() * 90_000));

    await this.prisma.otpCode.create({
      data: {
        email,
        code,
        expiresAt: new Date(Date.now() + AuthService.REGISTER_OTP_TTL_MS),
      },
    });

    const mailResult = await this.mail.sendRegisterCode(email, code);
    if (!mailResult.sent) {
      this.logger.error(
        { email, err: mailResult.error },
        'Register OTP email yuborilmadi',
      );
      throw new BadGatewayException("Email yuborib bo'lmadi");
    }

    return { ok: true };
  }

  async verifyRegisterEmailOtp(
    emailRaw: string,
    code: string,
  ): Promise<{ ok: true }> {
    const email = emailRaw.trim().toLowerCase();

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
    if (otp.attempts >= AuthService.REGISTER_OTP_MAX_ATTEMPTS) {
      throw new BadRequestException("Juda ko'p urinish. Yangi kod so'rang.");
    }
    if (otp.code !== code) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException("Noto'g'ri kod");
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { verifiedAt: new Date() },
    });

    return { ok: true };
  }

  // ── Device-link (QR orqali 2-qurilma ulash) ──
  // Qisqa muddatli kodlar in-memory saqlanadi (DB kerak emas — backend bitta
  // instance, 5 daqiqalik oyna; restart'da yo'qolsa zarar yo'q).
  private readonly _deviceLinks = new Map<
    string,
    { userId: string; expiresAt: number }
  >();
  private static readonly DEVICE_LINK_TTL_MS = 5 * 60 * 1000;
  private static readonly MAX_PARENT_DEVICES = 2;

  // ── Child re-pair (QR orqali yangi qurilmaga ulash) ──
  // Ota-ona QR generatsiya qiladi (har 45s yangilanadi), bola skanerlab
  // o'sha bolaga qayta ulanadi. Foydalanish holatlari:
  //   • Bola Parvoz ilovani o'chirib tashlagan / qayta o'rnatgan
  //   • Telefon zavod sozlamalariga qaytarilgan / yo'qolgan / almashtirilgan
  //   • FCM token yoki device ID o'zgargan
  // Family code bilan re-pair flow'idan farqi: bu **ota-ona aktiv** initiatsiya
  // qiladi (parent → QR → bola skaner), shuning uchun parent tasdiqi shart emas.
  private readonly _childRepairTokens = new Map<
    string,
    { parentId: string; childId: string; expiresAt: number }
  >();
  private static readonly CHILD_REPAIR_TTL_MS = 45 * 1000;

  /* ------------------------------------------------------------------ */
  /*  Token helpers                                                      */
  /* ------------------------------------------------------------------ */

  private signAccessToken(payload: JwtPayload): string {
    return this.jwtService.sign(
      {
        userId: payload.userId,
        role: payload.role,
        tokenVersion: payload.tokenVersion,
        ...(payload.sid && { sid: payload.sid }),
      },
      {
        secret: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
        expiresIn: this.config.get('JWT_ACCESS_EXPIRES', { infer: true }),
        audience: 'farzandim-consumer',
        issuer: 'farzandim-backend',
      },
    );
  }

  private signRefreshToken(payload: JwtPayload, rjti?: string): string {
    return this.jwtService.sign(
      {
        userId: payload.userId,
        role: payload.role,
        tokenVersion: payload.tokenVersion,
        ...(payload.sid && { sid: payload.sid }),
        ...(rjti && { rjti }),
      },
      {
        secret: this.config.get('JWT_REFRESH_SECRET', { infer: true }),
        expiresIn: this.config.get('JWT_REFRESH_EXPIRES', { infer: true }),
        audience: 'farzandim-consumer',
        issuer: 'farzandim-backend',
      },
    );
  }

  private verifyRefreshToken(token: string): JwtPayload & { rjti?: string } {
    return this.jwtService.verify<JwtPayload & { rjti?: string }>(token, {
      secret: this.config.get('JWT_REFRESH_SECRET', { infer: true }),
      audience: 'farzandim-consumer',
      issuer: 'farzandim-backend',
    });
  }

  /**
   * Qisqa muddatli "pending auth" tokeni — 2-qurilma limiti to'lganda login
   * javobida beriladi. Parolni qayta yubormasdan "session access" so'rovini
   * yaratish uchun foydalanuvchini isbotlaydi (10 daqiqa amal qiladi).
   */
  private signPendingAuthToken(userId: string): string {
    return this.jwtService.sign(
      { userId, purpose: 'session-access-pending' },
      {
        secret: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
        expiresIn: '10m',
        audience: 'farzandim-consumer',
        issuer: 'farzandim-backend',
      },
    );
  }

  private verifyPendingAuthToken(token: string): string {
    let decoded: { userId?: string; purpose?: string };
    try {
      decoded = this.jwtService.verify<{ userId?: string; purpose?: string }>(
        token,
        {
          secret: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
          audience: 'farzandim-consumer',
          issuer: 'farzandim-backend',
        },
      );
    } catch {
      throw new UnauthorizedException(
        "Ruxsat so'rovi muddati tugagan. Qaytadan kiring.",
      );
    }
    if (decoded.purpose !== 'session-access-pending' || !decoded.userId) {
      throw new UnauthorizedException("Yaroqsiz so'rov.");
    }
    return decoded.userId;
  }

  /**
   * Ota-ona akaunti uchun 2-qurilma limitini tekshiradi. Faol sessiya >= 2
   * bo'lsa — token bermay 409 DEVICE_LIMIT_REACHED + qisqa muddatli
   * pendingToken qaytaradi (ilova "ruxsat so'rash" ekranini ko'rsatadi).
   */
  private async enforceParentDeviceLimit(user: {
    id: string;
    role: string;
  }): Promise<void> {
    if (user.role !== 'PARENT') return;
    const active = await this.prisma.userSession.count({
      where: { userId: user.id, revokedAt: null },
    });
    if (active >= AuthService.MAX_PARENT_DEVICES) {
      throw new ConflictException({
        error: 'DEVICE_LIMIT_REACHED',
        message: "Bu akauntda 2 ta qurilma faol. Kirish uchun ruxsat so'rang.",
        pendingToken: this.signPendingAuthToken(user.id),
        maxDevices: AuthService.MAX_PARENT_DEVICES,
      });
    }
  }

  /* ------------------------------------------------------------------ */
  /*  Sessiya (Faol sessiyalar) — login'da yaratiladi                     */
  /* ------------------------------------------------------------------ */

  /**
   * Yangi sessiya yaratadi (qurilma + IP saqlaydi) va `{ sid, rjti }`
   * qaytaradi. Geo (shahar/davlat) fon rejimida aniqlanadi — login'ni
   * sekinlashtirmaslik uchun.
   */
  private async createSession(
    userId: string,
    device: DeviceMeta,
    reqMeta?: ReqMeta,
  ): Promise<{ sid: string; rjti: string }> {
    const rjti = randomUUID();
    const ip = extractClientIp(reqMeta);
    const userAgent =
      (reqMeta?.headers?.['user-agent'] as string | undefined) ?? null;

    const session = await this.prisma.userSession.create({
      data: {
        userId,
        jti: rjti,
        deviceModel: device.deviceModel?.trim() || null,
        platform: device.platform?.trim() || null,
        ipAddress: ip,
        userAgent: userAgent ? userAgent.slice(0, 400) : null,
      },
    });

    // Fire-and-forget geo — login javobini kutdirmaydi.
    void resolveGeo(ip).then((geo) => {
      if (geo.city || geo.country) {
        this.prisma.userSession
          .update({
            where: { id: session.id },
            data: { city: geo.city, country: geo.country },
          })
          .catch(() => undefined);
      }
    });

    return { sid: session.id, rjti };
  }

  /** access + refresh tokenlarni sid + rjti bilan imzolaydi. */
  private issueTokens(
    payload: JwtPayload,
    rjti?: string,
  ): { accessToken: string; refreshToken: string } {
    return {
      accessToken: this.signAccessToken(payload),
      refreshToken: this.signRefreshToken(payload, rjti),
    };
  }

  /* ------------------------------------------------------------------ */
  /*  Telegram Login                                                     */
  /* ------------------------------------------------------------------ */

  async telegramLogin(
    dto: TelegramAuthDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const data: TelegramAuthData = dto;

    if (!this.telegramService.verifyTelegramAuth(data)) {
      throw new UnauthorizedException('Invalid Telegram hash');
    }

    if (!this.telegramService.isAuthDataFresh(data.auth_date)) {
      throw new UnauthorizedException('Auth data expired');
    }

    const telegramId = String(data.id);
    const displayName =
      [data.first_name, data.last_name].filter(Boolean).join(' ') ||
      data.username ||
      `User${telegramId}`;

    const existing = await this.prisma.user.findUnique({ where: { telegramId } });

    const user = await this.prisma.user.upsert({
      where: { telegramId },
      update: {
        avatarUrl: data.photo_url ?? undefined,
      },
      create: {
        telegramId,
        role: 'PARENT',
        name: displayName,
        avatarUrl: data.photo_url,
      },
    });

    // Bloklangan hisob Telegram orqali ham kira olmasin (email login bilan bir
    // xil). Avval bu tekshiruv yo'q edi — banlangan foydalanuvchi /auth/telegram
    // orqali qayta token olib ban'ni chetlab o'ta olardi.
    if (!user.isActive) {
      throw new UnauthorizedException('Hisob bloklangan');
    }

    await this.audit.log(
      user.id,
      'auth',
      existing ? 'LOGIN' : 'CREATE',
      user.id,
      { telegramId, method: 'telegram' },
      reqMeta,
    );

    // buildAuthResponse orqali: 2-qurilma limiti (enforceParentDeviceLimit) va
    // yagona javob shakli. Avval createSession to'g'ridan-to'g'ri chaqirilardi —
    // bu qurilma limitini butunlay chetlab o'tardi.
    return this.buildAuthResponse(
      user,
      { deviceModel: dto.deviceModel, platform: dto.platform ?? 'web' },
      reqMeta,
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Google / Apple Social Login                                        */
  /* ------------------------------------------------------------------ */

  /**
   * Google ID token bilan login/register (single endpoint, upsert).
   * Mavjud foydalanuvchini topish tartibi:
   *   1) googleSub bo'yicha (avval ham Google bilan kirgan)
   *   2) email bo'yicha (boshqa usulda ro'yxatdan o'tgan — googleSub'ni bog'laymiz)
   *   3) topilmasa — yangi PARENT yaratiladi
   */
  async googleLogin(dto: SocialLoginDto, reqMeta?: ReqMeta) {
    const verified = await this.socialAuth.verifyGoogleIdToken(dto.idToken);
    return this.upsertSocialUser(verified, 'google', dto, reqMeta);
  }

  /**
   * Apple ID token bilan login/register. Apple `name`'ni faqat birinchi
   * roziligida yuboradi — Flutter alohida `name` field'da yuboradi.
   */
  async appleLogin(dto: SocialLoginDto, reqMeta?: ReqMeta) {
    const verified = await this.socialAuth.verifyAppleIdToken(dto.idToken);
    // Apple birinchi loginda name yuborgan bo'lsa, undan foydalanamiz.
    if (!verified.name && dto.name) {
      verified.name = dto.name;
    }
    return this.upsertSocialUser(verified, 'apple', dto, reqMeta);
  }

  /**
   * Social provider'dan kelgan tasdiqlangan foydalanuvchini DB'ga
   * yozadi/topadi va auth javobi (tokens + user) qaytaradi.
   */
  private async upsertSocialUser(
    verified: VerifiedSocialUser,
    provider: 'google' | 'apple',
    dto: SocialLoginDto,
    reqMeta?: ReqMeta,
  ) {
    const isGoogle = provider === 'google';
    const email = verified.email?.toLowerCase();

    // 1) Provider sub bo'yicha mavjud user'ni qidiramiz.
    let user = await this.prisma.user.findUnique({
      where: isGoogle
        ? { googleSub: verified.sub }
        : { appleSub: verified.sub },
    });

    let auditAction: 'CREATE' | 'LOGIN' = 'LOGIN';

    if (!user && email && verified.emailVerified) {
      // 2) Email bo'yicha topilsa — sub'ni o'sha akkauntga bog'laymiz.
      const byEmail = await this.prisma.user.findUnique({ where: { email } });
      if (byEmail) {
        user = await this.prisma.user.update({
          where: { id: byEmail.id },
          data: {
            ...(isGoogle
              ? { googleSub: verified.sub }
              : { appleSub: verified.sub }),
            // Avatar/name'ni faqat bo'sh bo'lsa yangilaymiz — foydalanuvchi
            // sozlamalardagi nomini buzmaymiz.
            ...(verified.picture && !byEmail.avatarUrl
              ? { avatarUrl: verified.picture }
              : {}),
            ...(verified.name && !byEmail.name
              ? { name: verified.name }
              : {}),
          },
        });
      }
    }

    if (!user) {
      // 3) Yangi user — PARENT roli bilan.
      user = await this.prisma.user.create({
        data: {
          role: 'PARENT',
          email: email ?? null,
          ...(isGoogle
            ? { googleSub: verified.sub }
            : { appleSub: verified.sub }),
          name: verified.name ?? null,
          avatarUrl: verified.picture ?? null,
        },
      });
      auditAction = 'CREATE';
      // Demo FAQAT telefon raqami orqali register uchun — Google/Apple
      // (email/social) login demo OLMAYDI (talab: faqat nomer orqali).
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Hisob bloklangan');
    }

    await this.audit.log(
      user.id,
      'auth',
      auditAction,
      user.id,
      { method: provider },
      reqMeta,
    );

    return this.buildAuthResponse(
      user,
      { deviceModel: dto.deviceModel, platform: dto.platform },
      reqMeta,
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Email / Telefon + Parol — Register & Login                         */
  /* ------------------------------------------------------------------ */

  /* ------------------------------------------------------------------ */
  /*  Parolni unutdim (logout) — OTP so'rash + tiklash                    */
  /* ------------------------------------------------------------------ */

  /**
   * Logout holatida parol tiklash uchun OTP yuboradi (telefon SMS yoki email).
   * Enumeration himoyasi: akkaunt topilmasa ham generic "ok" qaytadi (mavjudlik
   * oshkor qilinmaydi), lekin haqiqiy SMS/email faqat mavjud akkauntga ketadi.
   */
  async forgotPasswordRequest(
    dto: ForgotPasswordRequestDto,
  ): Promise<{ ok: true; message: string }> {
    const phone = dto.phone?.trim();
    const email = dto.email?.trim().toLowerCase();
    if (!phone && !email) {
      throw new BadRequestException('Telefon yoki email kiriting');
    }
    const generic = {
      ok: true as const,
      message: "Agar akkaunt mavjud bo'lsa, tasdiqlash kodi yuborildi",
    };

    const user = await this.prisma.user.findFirst({
      where: phone ? { phone } : { email },
      select: { id: true },
    });
    // Akkaunt yo'q — mavjudlikni oshkor qilmaymiz (generic javob).
    if (!user) return generic;

    const isPhone = Boolean(phone);
    const target = (phone ?? email)!;

    // 60s cooldown (spam himoyasi).
    const recent = await this.prisma.otpCode.findFirst({
      where: {
        ...(isPhone ? { phone: target } : { email: target }),
        createdAt: {
          gt: new Date(Date.now() - AuthService.REGISTER_OTP_RESEND_COOLDOWN_MS),
        },
      },
    });
    if (recent) {
      throw new BadRequestException('Kod yaqinda yuborildi. Biroz kuting.');
    }

    const code = String(Math.floor(10_000 + Math.random() * 90_000));

    // Avval yuboramiz: yuborib bo'lmasa OtpCode yozilmaydi (cooldown haqiqiy
    // qayta urinishni bloklamasin).
    if (isPhone) {
      if (!this.sms.isSmsConfigured()) {
        throw new ServiceUnavailableException('SMS xizmati hozircha mavjud emas');
      }
      const r = await this.sms.sendRegisterCode(target, code);
      if (!r.sent) {
        this.logger.error({ err: r.error }, 'Parol tiklash SMS yuborilmadi');
        throw new BadGatewayException("SMS yuborib bo'lmadi");
      }
    } else {
      if (!this.mail.isMailConfigured()) {
        throw new ServiceUnavailableException(
          'Email xizmati hozircha mavjud emas',
        );
      }
      const r = await this.mail.sendVerifyCode(target, code);
      if (!r.sent) {
        this.logger.error({ err: r.error }, 'Parol tiklash email yuborilmadi');
        throw new BadGatewayException("Email yuborib bo'lmadi");
      }
    }

    await this.prisma.otpCode.create({
      data: {
        ...(isPhone ? { phone: target } : { email: target }),
        code,
        expiresAt: new Date(Date.now() + AuthService.REGISTER_OTP_TTL_MS),
      },
    });
    return generic;
  }

  /**
   * OTP kodni tekshirib logout holatida yangi parol o'rnatadi.
   */
  async forgotPasswordReset(
    dto: ForgotPasswordResetDto,
  ): Promise<{ ok: true }> {
    const phone = dto.phone?.trim();
    const email = dto.email?.trim().toLowerCase();
    if (!phone && !email) {
      throw new BadRequestException('Telefon yoki email kiriting');
    }
    const user = await this.prisma.user.findFirst({
      where: phone ? { phone } : { email },
      select: { id: true },
    });
    const badCode = () =>
      new BadRequestException('Kod topilmadi yoki muddati tugagan');
    if (!user) throw badCode();

    const isPhone = Boolean(phone);
    const target = (phone ?? email)!;
    const otp = await this.prisma.otpCode.findFirst({
      where: {
        ...(isPhone ? { phone: target } : { email: target }),
        verifiedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) throw badCode();
    if (otp.attempts >= AuthService.REGISTER_OTP_MAX_ATTEMPTS) {
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
        where: { id: user.id },
        data: { passwordHash },
      }),
    ]);
    return { ok: true };
  }

  /**
   * Ota-ona (PARENT) ro'yxatdan o'tishi — email yoki telefon + parol.
   * Kamida bittasi (email yoki phone) berilishi shart.
   */
  async register(
    dto: RegisterDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const email = dto.email?.trim().toLowerCase() || undefined;
    const phone = dto.phone?.trim() || undefined;

    if (!email && !phone) {
      throw new BadRequestException(
        'Email yoki telefon raqamdan kamida bittasi kerak',
      );
    }

    // Takrorlanish tekshiruvi
    if (email) {
      const exists = await this.prisma.user.findUnique({ where: { email } });
      if (exists) {
        throw new ConflictException("Bu email allaqachon ro'yxatdan o'tgan");
      }

      // ── Email OTP tasdiqlanganligi MAJBURIY (SMS bilan bir xil) ──
      // `POST /auth/verify-register-email-otp` to'g'ri kod bilan oldindan
      // chaqirilgan bo'lishi shart — aks holda email verification chetlab
      // o'tilyapti. Faqat SMTP sozlangan bo'lsa talab qilamiz; sozlanmagan
      // bo'lsa email-OTP umuman ishlamaydi, eski xulq buzilmasin.
      if (this.mail.isMailConfigured()) {
        const verifiedOtp = await this.prisma.otpCode.findFirst({
          where: {
            email,
            verifiedAt: {
              not: null,
              gt: new Date(
                Date.now() - AuthService.REGISTER_OTP_VERIFIED_VALIDITY_MS,
              ),
            },
          },
          orderBy: { verifiedAt: 'desc' },
        });
        if (!verifiedOtp) {
          throw new UnauthorizedException(
            'Email tasdiqlanmagan. Iltimos, kodni qayta tasdiqlang.',
          );
        }
      }
    }
    if (phone) {
      const exists = await this.prisma.user.findUnique({ where: { phone } });
      if (exists) {
        throw new ConflictException(
          "Bu telefon raqam allaqachon ro'yxatdan o'tgan",
        );
      }

      // ── SMS OTP tasdiqlanganligi MAJBURIY ──
      // Avval `POST /auth/verify-register-otp` to'g'ri kod bilan chaqirilgan
      // bo'lishi shart — DB'da `verifiedAt`'i to'lgan, 10 daqiqada eskirmagan
      // yozuv bor. Bu yo'q bo'lsa, foydalanuvchi `/register`'ga to'g'ridan
      // murojaat qilib SMS verification'ni chetlab o'tishga harakat qilyapti.
      const verifiedOtp = await this.prisma.otpCode.findFirst({
        where: {
          phone,
          verifiedAt: {
            not: null,
            gt: new Date(
              Date.now() - AuthService.REGISTER_OTP_VERIFIED_VALIDITY_MS,
            ),
          },
        },
        orderBy: { verifiedAt: 'desc' },
      });
      if (!verifiedOtp) {
        throw new UnauthorizedException(
          "Telefon raqam SMS orqali tasdiqlanmagan. Iltimos, kodni qayta tasdiqlang.",
        );
      }
    }

    const passwordHash = await hashPassword(dto.password);

    const user = await this.prisma.user.create({
      data: {
        role: 'PARENT',
        email: email ?? null,
        phone: phone ?? null,
        passwordHash,
        name: dto.name?.trim() || null,
      },
    });

    // 1-haftalik Standart demo FAQAT telefon raqami orqali ro'yxatdan
    // o'tganlarga beriladi (email orqali register — demo OLMAYDI).
    if (phone) {
      await this.trial.grantStandardTrial(user.id);
    }

    // OTP'ni ishlatib bo'ldik — DB'dan tozalab qo'yamiz (replay attack
    // himoyasi: bir tasdiqlash bilan bir necha akkaunt yaratish mumkin
    // bo'lmasligi uchun). Phone'siz registration uchun no-op.
    if (phone) {
      await this.prisma.otpCode
        .deleteMany({ where: { phone } })
        .catch(() => undefined);
    }
    if (email) {
      await this.prisma.otpCode
        .deleteMany({ where: { email } })
        .catch(() => undefined);
    }

    await this.audit.log(
      user.id,
      'auth',
      'CREATE',
      user.id,
      { method: email ? 'email' : 'phone' },
      reqMeta,
    );

    return this.buildAuthResponse(
      user,
      { deviceModel: dto.deviceModel, platform: dto.platform },
      reqMeta,
    );
  }

  /**
   * Email yoki telefon + parol bilan kirish.
   * Xavfsizlik: user topilmasa ham, parol noto'g'ri ham — bir xil xabar.
   */
  async login(
    dto: LoginDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const identifier = dto.identifier.trim();
    const isEmail = identifier.includes('@');

    const user = await this.prisma.user.findUnique({
      where: isEmail
        ? { email: identifier.toLowerCase() }
        : { phone: identifier },
    });

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException("Login yoki parol noto'g'ri");
    }

    const valid = await verifyPassword(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException("Login yoki parol noto'g'ri");
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Hisob bloklangan');
    }

    await this.audit.log(
      user.id,
      'auth',
      'LOGIN',
      user.id,
      { method: isEmail ? 'email' : 'phone' },
      reqMeta,
    );

    return this.buildAuthResponse(
      user,
      { deviceModel: dto.deviceModel, platform: dto.platform },
      reqMeta,
    );
  }

  /**
   * Login/register javobini quradi: tokens + minimal user obyekti.
   * Telegram login bilan bir xil shaklda (Flutter AuthSession.fromJson).
   */
  private async buildAuthResponse(
    user: {
      id: string;
      role: string;
      name: string | null;
      avatarUrl: string | null;
      telegramId: string | null;
      language: string;
      tokenVersion: number;
    },
    device: DeviceMeta = {},
    reqMeta?: ReqMeta,
  ) {
    // 2-qurilma limiti — faol seans >= 2 bo'lsa token bermay 409 + pendingToken.
    await this.enforceParentDeviceLimit(user);
    const { sid, rjti } = await this.createSession(user.id, device, reqMeta);
    const payload: JwtPayload = {
      userId: user.id,
      role: user.role as 'PARENT' | 'CHILD',
      tokenVersion: user.tokenVersion,
      sid,
    };
    const { accessToken, refreshToken } = this.issueTokens(payload, rjti);

    return {
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
        avatarUrl: user.avatarUrl,
        telegramId: user.telegramId,
        language: user.language,
      },
      accessToken,
      refreshToken,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  Device-link — QR orqali ikkinchi qurilma ulash                      */
  /* ------------------------------------------------------------------ */

  /** Eskirgan kodlarni tozalaydi. */
  private pruneDeviceLinks(): void {
    const now = Date.now();
    for (const [code, v] of this._deviceLinks) {
      if (v.expiresAt < now) this._deviceLinks.delete(code);
    }
  }

  /**
   * Mas'ul qurilmada chaqiriladi — QR uchun qisqa muddatli kod yaratadi.
   * Bu kodni faqat shu akkaunt egasi yaratadi → boshqa qurilma uni
   * skanerlab kirsa, bu egasining ruxsati hisoblanadi.
   */
  createDeviceLink(userId: string): { code: string; expiresInSec: number } {
    this.pruneDeviceLinks();
    const code = randomUUID().replace(/-/g, '');
    this._deviceLinks.set(code, {
      userId,
      expiresAt: Date.now() + AuthService.DEVICE_LINK_TTL_MS,
    });
    return {
      code,
      expiresInSec: Math.floor(AuthService.DEVICE_LINK_TTL_MS / 1000),
    };
  }

  /**
   * Yangi qurilma QR kodni skanerlab kiradi — parent tokenlarini oladi.
   * Maks 2 qurilma: mas'ul (eng eski sessiya) saqlanadi; agar allaqachon
   * 2 ta faol sessiya bo'lsa, egasidan boshqa hammasi chiqariladi va yangi
   * qurilma 2-chi bo'ladi (egasi QR yaratgani uchun bu uning tasdiqi).
   */
  async redeemDeviceLink(
    code: string,
    device: DeviceMeta = {},
    reqMeta?: ReqMeta,
  ) {
    this.pruneDeviceLinks();
    const entry = this._deviceLinks.get(code);
    if (!entry || entry.expiresAt < Date.now()) {
      throw new UnauthorizedException('QR kod yaroqsiz yoki muddati tugagan');
    }
    this._deviceLinks.delete(code); // bir martalik

    const user = await this.prisma.user.findUnique({
      where: { id: entry.userId },
    });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Akkaunt topilmadi yoki bloklangan');
    }

    // Maks 2 qurilma — egasidan (eng eski sessiya) boshqasini chiqaramiz.
    const active = await this.prisma.userSession.findMany({
      where: { userId: user.id, revokedAt: null },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (active.length >= AuthService.MAX_PARENT_DEVICES) {
      const toRevoke = active.slice(1).map((s) => s.id); // egasi (index 0) qoladi
      if (toRevoke.length > 0) {
        await this.prisma.userSession.updateMany({
          where: { id: { in: toRevoke } },
          data: { revokedAt: new Date() },
        });
      }
    }

    await this.audit.log(
      user.id,
      'auth',
      'DEVICE_LINK_REDEEM',
      user.id,
      { platform: device.platform },
      reqMeta,
    );

    return this.buildAuthResponse(user, device, reqMeta);
  }

  /* ------------------------------------------------------------------ */
  /*  Child Re-pair — QR orqali yangi qurilmaga ulash                    */
  /* ------------------------------------------------------------------ */

  /** Eskirgan repair tokenlarni tozalaydi. */
  private pruneChildRepairTokens(): void {
    const now = Date.now();
    for (const [token, v] of this._childRepairTokens) {
      if (v.expiresAt < now) this._childRepairTokens.delete(token);
    }
  }

  /**
   * Ota-onada chaqiriladi (bolalar ro'yxati → "Qayta ulash"). 45s yashaydigan
   * token yaratadi. Ota-ona uni QR ko'rinishida ko'rsatadi, bola skanerlaydi.
   * Egalik tekshiruvi: faqat shu bolaning ota-onasi token chiqara oladi.
   */
  async createChildRepairToken(
    parentId: string,
    childId: string,
  ): Promise<{ token: string; expiresInSec: number }> {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
      select: { id: true, parentId: true },
    });
    if (!child) throw new NotFoundException('Bola topilmadi');
    if (child.parentId !== parentId) {
      throw new UnauthorizedException(
        "Faqat bolaning ota-onasi qayta ulash QR'ini yaratishi mumkin",
      );
    }

    this.pruneChildRepairTokens();
    const token = randomUUID().replace(/-/g, '');
    this._childRepairTokens.set(token, {
      parentId,
      childId,
      expiresAt: Date.now() + AuthService.CHILD_REPAIR_TTL_MS,
    });
    return {
      token,
      expiresInSec: Math.floor(AuthService.CHILD_REPAIR_TTL_MS / 1000),
    };
  }

  /**
   * Bola QR kodni skanerlab kiradi. Token tekshiriladi, yangi User
   * (CHILD) yaratiladi, eski childUserId yangisi bilan almashtiriladi.
   * Eski qurilma sessiyasi (agar bo'lsa) bekor qilinadi — eski telefon
   * boshqa kira olmaydi.
   *
   * Parent app'ga WebSocket `child:repaired` event yuboriladi (modal
   * yopish + child list yangilash uchun).
   */
  async redeemChildRepairToken(
    token: string,
    device: DeviceMeta = {},
    reqMeta?: ReqMeta,
  ) {
    this.pruneChildRepairTokens();
    const entry = this._childRepairTokens.get(token);
    if (!entry || entry.expiresAt < Date.now()) {
      throw new UnauthorizedException(
        'QR kod yaroqsiz yoki muddati tugagan. Ota-onadan yangi kod oling.',
      );
    }
    this._childRepairTokens.delete(token); // bir martalik

    const child = await this.prisma.child.findUnique({
      where: { id: entry.childId },
    });
    if (!child) {
      throw new NotFoundException('Bola yo\'q (o\'chirilgan?)');
    }

    // Eski child user sessiyalarini bekor qilamiz (eski telefon endi
    // bu akkauntga kira olmaydi). "Bir bola = bir qurilma" qoidasi.
    const oldChildUserId = child.childUserId;
    if (oldChildUserId) {
      await this.prisma.userSession.updateMany({
        where: { userId: oldChildUserId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      // tokenVersion'ni oshirish refresh tokenlarni darhol bekor qiladi.
      // isActive=false → keyingi login/refresh urinishlari ham rad etiladi.
      await this.prisma.user
        .update({
          where: { id: oldChildUserId },
          data: {
            isActive: false,
            tokenVersion: { increment: 1 },
          },
        })
        .catch(() => undefined);
      // FCM tokens tozalanadi — eski qurilmaga push xabarlar ketmaydi.
      await this.prisma.fcmToken
        .deleteMany({ where: { userId: oldChildUserId } })
        .catch(() => undefined);
    }

    // Yangi child User yaratamiz.
    const user = await this.prisma.user.create({
      data: {
        role: 'CHILD',
        name: child.name,
      },
    });

    // Bola yozuvini yangi User'ga bog'laymiz.
    const updated = await this.prisma.child.update({
      where: { id: child.id },
      data: {
        childUserId: user.id,
        isConnected: true,
        pairedAt: new Date(),
        ...(device.deviceModel && { deviceModel: device.deviceModel }),
      },
    });

    await this.audit.log(
      user.id,
      'auth',
      'PAIR',
      user.id,
      {
        childId: child.id,
        method: 'qr_repair',
        previousChildUserId: oldChildUserId,
      },
      reqMeta,
    );

    // Real-time: ota-ona ekraniga "muvaffaqiyatli ulandi" signal.
    this.realtime.emitToUser(child.parentId, 'child:repaired', {
      childId: child.id,
      childName: child.name,
      newChildUserId: user.id,
      pairedAt: updated.pairedAt?.toISOString(),
    });

    // Eski qurilmaga "siz unpair bo'ldingiz" — UI lokal prefs'ni tozalab
    // /pairing ekraniga qaytadi. WebSocket hali tirik bo'lsa darhol ushlaydi.
    if (oldChildUserId) {
      this.realtime.emitToUser(oldChildUserId, 'child:unpaired', {
        childId: child.id,
        reason: 'QR_REPAIR_REDEEMED',
        at: new Date().toISOString(),
      });
    }

    const payload: JwtPayload = {
      userId: user.id,
      role: user.role as 'PARENT' | 'CHILD',
      tokenVersion: user.tokenVersion,
    };
    const accessToken = this.signAccessToken(payload);
    const refreshToken = this.signRefreshToken(payload);

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
        avatarUrl: user.avatarUrl,
        telegramId: user.telegramId,
        language: user.language,
      },
      child: {
        id: updated.id,
        parentId: updated.parentId,
        name: updated.name,
        age: updated.age,
      },
    };
  }

  /* ------------------------------------------------------------------ */
  /*  Refresh Token (with rotation + tokenVersion check)                 */
  /* ------------------------------------------------------------------ */

  async refreshToken(token: string) {
    let payload: JwtPayload & { rjti?: string };
    try {
      payload = this.verifyRefreshToken(token);
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.userId },
    });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or inactive');
    }

    // tokenVersion mismatch means "logout everywhere" was called => reject
    if ((payload.tokenVersion ?? 0) !== user.tokenVersion) {
      throw new UnauthorizedException('Token revoked');
    }

    // ── Sessiya-asosli tokenlar (sid bor) — revoke + rotation tekshiruvi ──
    let newRjti: string | undefined;
    if (payload.sid) {
      const session = await this.prisma.userSession.findUnique({
        where: { id: payload.sid },
      });
      if (!session || session.revokedAt) {
        throw new UnauthorizedException('Session revoked');
      }
      // rjti mos kelmasa — bu refresh token allaqachon rotatsiya qilingan
      // (eski nusxa).
      //
      // AVVAL: butun sessiyani revoke qilardik ("o'g'irlangan token belgisi").
      // MUAMMO: bola ilovasida UI-isolate + background-isolate (heartbeat/
      // lokatsiya) ALOHIDA Dio bilan bir vaqtda /auth/refresh chaqiradi va
      // ikkovi ham AYNI refresh tokenni yuboradi. "Yutqazgan" isolate eski
      // rjti bilan kelib, butun sessiyani revoke qilardi → bola O'ZIDAN-O'ZI
      // CHIQIB KETARDI. Bu 15 daqiqalik access token har tugaganda takror
      // bo'lardi (foydalanuvchi shikoyati: "o'zidan o'zi chiqib ketyapti").
      //
      // ENDI: revoke QILMAYMIZ — shunchaki rad etamiz (401). Yutqazgan isolate
      // storage'dagi YANGI (rotatsiyalangan) tokenni o'qib davom etadi (klient
      // tomonda tuzatilgan). Xavfsizlik saqlanadi: o'g'irlangan eski token jti
      // mos kelmagani uchun baribir yangi token ololmaydi; "hamma joydan
      // chiqish" esa tokenVersion + session.revokedAt orqali ishlaydi.
      if (payload.rjti && session.jti !== payload.rjti) {
        throw new UnauthorizedException('Session rotated');
      }
      newRjti = randomUUID();
      await this.prisma.userSession.update({
        where: { id: session.id },
        data: { jti: newRjti, lastSeenAt: new Date() },
      });
    }

    const newPayload: JwtPayload = {
      userId: user.id,
      role: user.role as 'PARENT' | 'CHILD',
      tokenVersion: user.tokenVersion,
      sid: payload.sid,
    };

    return this.issueTokens(newPayload, newRjti);
  }

  /* ------------------------------------------------------------------ */
  /*  Child Pair                                                         */
  /* ------------------------------------------------------------------ */

  async childPair(
    dto: ChildPairDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({
      where: { familyCode: dto.familyCode },
    });
    if (!child) {
      throw new NotFoundException('Family code not found');
    }

    // Bola allaqachon boshqa qurilmaga ulangan → oila-kodi QR bilan qayta
    // ulash TO'LIQ BLOKLANADI (bir bola = bir qurilma, qat'iy). Avval bu yerda
    // "ota-ona tasdiqlaydi" so'rovi yaratilardi va yangi qurilma o'tib olardi —
    // bu xato edi: ulangan bola profilini boshqa telefonga ko'chirib bo'lardi.
    //
    // Yangi qurilmaga o'tish uchun LEGAL yo'llar (ota-ona ilovasida):
    //   1) Oila kodini qayta generatsiya qilish (joriy qurilma uziladi), yoki
    //   2) "Qayta ulash" (repair) QR kodini olish (`createChildRepairToken`).
    if (child.childUserId) {
      await this.audit.log(
        null,
        'auth',
        'PAIR',
        child.id,
        {
          action: 'REPAIR_BLOCKED_ALREADY_PAIRED',
          childId: child.id,
          familyCode: dto.familyCode,
        },
        reqMeta,
      );
      throw new ConflictException({
        error: 'ALREADY_PAIRED',
        message:
          'Bu bola allaqachon boshqa qurilmaga ulangan. Yangi qurilmaga ' +
          'ulash uchun ota-ona ilovasidan joriy qurilmani uzing yoki ' +
          '"Qayta ulash" QR kodini oling.',
      });
    }

    // Fresh pair: create User for child
    const user = await this.prisma.user.create({
      data: {
        role: 'CHILD',
        name: child.name,
      },
    });

    const deviceInfo = dto.deviceInfo;
    const updatedChild = await this.prisma.child.update({
      where: { id: child.id },
      data: {
        childUserId: user.id,
        isConnected: true,
        pairedAt: new Date(),
        ...(deviceInfo?.model && { deviceModel: deviceInfo.model }),
        ...(deviceInfo?.batteryLevel !== undefined && {
          batteryLevel: deviceInfo.batteryLevel,
        }),
        ...(deviceInfo?.isCharging !== undefined && {
          isCharging: deviceInfo.isCharging,
        }),
      },
    });

    const payload: JwtPayload = {
      userId: user.id,
      role: user.role as 'PARENT' | 'CHILD',
      tokenVersion: user.tokenVersion,
    };
    const accessToken = this.signAccessToken(payload);
    const refreshToken = this.signRefreshToken(payload);

    await this.audit.log(
      user.id,
      'auth',
      'PAIR',
      user.id,
      { childId: updatedChild.id, familyCode: dto.familyCode },
      reqMeta,
    );

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
        avatarUrl: user.avatarUrl,
        telegramId: user.telegramId,
        language: user.language,
      },
      child: {
        id: updatedChild.id,
        parentId: updatedChild.parentId,
        name: updatedChild.name,
        age: updatedChild.age,
      },
    };
  }

  /* ------------------------------------------------------------------ */
  /*  Child Pair Status (polling endpoint for re-pair flow)              */
  /* ------------------------------------------------------------------ */

  async childPairStatus(pairRequestId: string) {
    const pairRequest = await this.prisma.childPairRequest.findUnique({
      where: { id: pairRequestId },
      include: { child: true },
    });

    if (!pairRequest) {
      throw new NotFoundException('Pair request not found');
    }

    // Check if expired
    if (
      pairRequest.status === 'PENDING' &&
      pairRequest.expiresAt < new Date()
    ) {
      await this.prisma.childPairRequest.update({
        where: { id: pairRequestId },
        data: { status: 'EXPIRED', decidedAt: new Date() },
      });
      return { status: 'EXPIRED' };
    }

    // APPROVED — bolaga JWT, user va child obyektlarini qaytaramiz.
    // Approve oqimi eski qurilmani allaqachon majburan chiqargan (session
    // revoke + tokenVersion++ + isActive=false). Yangi qurilma shu polling
    // orqali tokenni oladi va paired holatga o'tadi.
    if (pairRequest.status === 'APPROVED' && pairRequest.newUserId) {
      const newUser = await this.prisma.user.findUnique({
        where: { id: pairRequest.newUserId },
      });
      if (!newUser) {
        // newUserId saqlangan, lekin User yo'q — anomaliya. Fallback:
        // shunchaki status qaytarib, child app qayta urinib ko'rsin.
        return { status: pairRequest.status };
      }

      const payload: JwtPayload = {
        userId: newUser.id,
        role: newUser.role as 'PARENT' | 'CHILD',
        tokenVersion: newUser.tokenVersion,
      };
      const accessToken = this.signAccessToken(payload);
      const refreshToken = this.signRefreshToken(payload);

      return {
        status: 'APPROVED',
        accessToken,
        refreshToken,
        user: {
          id: newUser.id,
          name: newUser.name,
          role: newUser.role,
          avatarUrl: newUser.avatarUrl,
          telegramId: newUser.telegramId,
          language: newUser.language,
        },
        child: {
          id: pairRequest.child.id,
          parentId: pairRequest.child.parentId,
          name: pairRequest.child.name,
          age: pairRequest.child.age,
        },
      };
    }

    return { status: pairRequest.status };
  }

  /* ------------------------------------------------------------------ */
  /*  Session access — 2-qurilma limit (3-qurilma kirish so'rovi)         */
  /* ------------------------------------------------------------------ */

  private deviceLabel(
    deviceModel?: string | null,
    platform?: string | null,
  ): string {
    const m = deviceModel?.trim();
    if (m) return m;
    const p = platform?.trim().toLowerCase();
    if (p === 'ios') return 'iPhone';
    if (p === 'android') return 'Android qurilma';
    if (p === 'web') return 'Brauzer';
    return 'Yangi qurilma';
  }

  /**
   * "Ruxsat so'rash" — pendingToken bilan isbotlangan foydalanuvchi uchun
   * yangi kirish so'rovi yaratadi va 2 ta ulangan qurilmaga push + realtime
   * yuboradi. Qaytaradi { requestId, pollToken } — so'rovchi shular bilan poll qiladi.
   */
  async requestSessionAccess(
    dto: { pendingToken: string; deviceModel?: string; platform?: string },
    reqMeta?: ReqMeta,
  ): Promise<{
    requestId: string;
    pollToken: string;
    pollIntervalSec: number;
    expiresAt: string;
  }> {
    const userId = this.verifyPendingAuthToken(dto.pendingToken);
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Hisob topilmadi yoki bloklangan.');
    }

    // Bir vaqtda bitta faol so'rov — eski ochiqlarni yopamiz.
    await this.prisma.sessionAccessRequest.updateMany({
      where: { userId, status: 'PENDING' },
      data: { status: 'EXPIRED', decidedAt: new Date() },
    });

    const pollToken = randomUUID();
    const ip = extractClientIp(reqMeta);
    const userAgent =
      (reqMeta?.headers?.['user-agent'] as string | undefined) ?? null;
    const expiresAt = new Date(Date.now() + SESSION_ACCESS_TTL_MS);

    const request = await this.prisma.sessionAccessRequest.create({
      data: {
        userId,
        pollToken,
        deviceModel: dto.deviceModel?.trim() || null,
        platform: dto.platform?.trim() || null,
        ipAddress: ip,
        userAgent: userAgent ? userAgent.slice(0, 400) : null,
        expiresAt,
      },
    });

    const label = this.deviceLabel(dto.deviceModel, dto.platform);
    const payload = {
      id: request.id,
      deviceModel: request.deviceModel,
      platform: request.platform,
      ipAddress: request.ipAddress,
      createdAt: request.createdAt.toISOString(),
      expiresAt: request.expiresAt.toISOString(),
    };

    // Ikkala ulangan qurilmaga jonli signal + push.
    this.realtime.emitToUser(userId, 'session_access:created', payload);
    const accessLang = await this.fcm.getUserLang(userId);
    void this.fcm
      .sendPushToUser(userId, {
        title: tr(accessLang, 'sessionAccess.title'),
        body: tr(accessLang, 'sessionAccess.body', { label }),
        data: {
          type: 'session_access_request',
          sessionRequestId: request.id,
          deviceModel: request.deviceModel ?? '',
          platform: request.platform ?? '',
        },
      })
      .catch((err) =>
        this.logger.warn(
          { err, requestId: request.id },
          'session_access push failed',
        ),
      );

    await this.audit.log(
      userId,
      'auth',
      'SESSION_ACCESS_REQUEST',
      request.id,
      { deviceModel: request.deviceModel },
      reqMeta,
    );

    return {
      requestId: request.id,
      pollToken,
      pollIntervalSec: 3,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /**
   * So'rovchi qurilma poll qiladi. APPROVED bo'lib slot bo'shagach (faol
   * seans < 2) — sessiya yaratib token qaytaradi (doim max 2 saqlanadi).
   */
  async sessionAccessStatus(
    requestId: string,
    pollToken: string,
    reqMeta?: ReqMeta,
  ) {
    const request = await this.prisma.sessionAccessRequest.findUnique({
      where: { id: requestId },
    });
    if (!request || request.pollToken !== pollToken) {
      throw new NotFoundException("So'rov topilmadi.");
    }

    if (request.status === 'PENDING' && request.expiresAt < new Date()) {
      await this.prisma.sessionAccessRequest.update({
        where: { id: requestId },
        data: { status: 'EXPIRED', decidedAt: new Date() },
      });
      return { status: 'EXPIRED' as const };
    }

    if (request.status !== 'APPROVED') {
      return { status: request.status };
    }
    if (request.consumedAt) {
      return { status: 'CONSUMED' as const };
    }

    // Approved — lekin slot bo'sh bo'lishi kerak (faol seans < 2).
    const active = await this.prisma.userSession.count({
      where: { userId: request.userId, revokedAt: null },
    });
    if (active >= AuthService.MAX_PARENT_DEVICES) {
      return { status: 'APPROVED' as const, slotFree: false };
    }

    // Atomik "claim" — bir nechta poll bir vaqtda kelsa, bittasi yutadi.
    const claim = await this.prisma.sessionAccessRequest.updateMany({
      where: { id: requestId, status: 'APPROVED', consumedAt: null },
      data: { consumedAt: new Date() },
    });
    if (claim.count === 0) {
      return { status: 'CONSUMED' as const };
    }

    const user = await this.prisma.user.findUnique({
      where: { id: request.userId },
    });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Hisob topilmadi yoki bloklangan.');
    }

    const { sid, rjti } = await this.createSession(
      user.id,
      {
        deviceModel: request.deviceModel ?? undefined,
        platform: request.platform ?? undefined,
      },
      reqMeta,
    );
    const payload: JwtPayload = {
      userId: user.id,
      role: user.role as 'PARENT' | 'CHILD',
      tokenVersion: user.tokenVersion,
      sid,
    };
    const { accessToken, refreshToken } = this.issueTokens(payload, rjti);

    return {
      status: 'APPROVED' as const,
      slotFree: true,
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
        avatarUrl: user.avatarUrl,
        telegramId: user.telegramId,
        language: user.language,
      },
    };
  }

  /** Ulangan qurilma so'rovni tasdiqlaydi. */
  async approveSessionAccess(userId: string, requestId: string) {
    const request = await this.prisma.sessionAccessRequest.findUnique({
      where: { id: requestId },
    });
    if (!request || request.userId !== userId) {
      throw new NotFoundException("So'rov topilmadi.");
    }
    if (request.status === 'APPROVED') {
      return { status: 'APPROVED' as const };
    }
    if (request.status !== 'PENDING') {
      throw new BadRequestException(`So'rov allaqachon ${request.status}.`);
    }
    if (request.expiresAt < new Date()) {
      await this.prisma.sessionAccessRequest.update({
        where: { id: requestId },
        data: { status: 'EXPIRED', decidedAt: new Date() },
      });
      throw new BadRequestException("So'rov muddati tugagan.");
    }
    await this.prisma.sessionAccessRequest.update({
      where: { id: requestId },
      data: { status: 'APPROVED', decidedAt: new Date() },
    });
    this.realtime.emitToUser(userId, 'session_access:decided', {
      id: requestId,
      status: 'APPROVED',
    });
    return { status: 'APPROVED' as const };
  }

  /** Ulangan qurilma so'rovni rad etadi. */
  async rejectSessionAccess(userId: string, requestId: string) {
    const request = await this.prisma.sessionAccessRequest.findUnique({
      where: { id: requestId },
    });
    if (!request || request.userId !== userId) {
      throw new NotFoundException("So'rov topilmadi.");
    }
    if (request.status === 'REJECTED') {
      return { status: 'REJECTED' as const };
    }
    if (request.status !== 'PENDING') {
      throw new BadRequestException(`So'rov allaqachon ${request.status}.`);
    }
    await this.prisma.sessionAccessRequest.update({
      where: { id: requestId },
      data: { status: 'REJECTED', decidedAt: new Date() },
    });
    this.realtime.emitToUser(userId, 'session_access:decided', {
      id: requestId,
      status: 'REJECTED',
    });
    return { status: 'REJECTED' as const };
  }

  /** Ulangan qurilma uchun ochiq so'rovlar (tasdiqlash UI). */
  async listPendingSessionAccess(userId: string) {
    await this.prisma.sessionAccessRequest.updateMany({
      where: { userId, status: 'PENDING', expiresAt: { lt: new Date() } },
      data: { status: 'EXPIRED', decidedAt: new Date() },
    });
    const rows = await this.prisma.sessionAccessRequest.findMany({
      where: { userId, status: 'PENDING' },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => ({
      id: r.id,
      deviceModel: r.deviceModel,
      platform: r.platform,
      ipAddress: r.ipAddress,
      createdAt: r.createdAt.toISOString(),
      expiresAt: r.expiresAt.toISOString(),
    }));
  }

  /** Eskirgan PENDING so'rovlarni EXPIRED qiladi (har 5 daqiqada). */
  @Cron('30 */5 * * * *', { name: 'session-access-expire' })
  async expireStaleSessionAccess(): Promise<void> {
    await this.prisma.sessionAccessRequest.updateMany({
      where: { status: 'PENDING', expiresAt: { lt: new Date() } },
      data: { status: 'EXPIRED', decidedAt: new Date() },
    });
  }

  /* ------------------------------------------------------------------ */
  /*  Logout — increment tokenVersion, all refresh tokens become invalid */
  /* ------------------------------------------------------------------ */

  async logout(userId: string, sid?: string): Promise<{ ok: true }> {
    if (sid) {
      // Faqat shu qurilma sessiyasini tugatamiz (boshqa qurilmalar qoladi).
      await this.prisma.userSession.updateMany({
        where: { id: sid, userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else {
      // Legacy (sid yo'q token) — barcha refresh tokenlarni bekor qilamiz.
      await this.prisma.user.update({
        where: { id: userId },
        data: { tokenVersion: { increment: 1 } },
      });
    }
    return { ok: true };
  }

  /* ------------------------------------------------------------------ */
  /*  Faol sessiyalar — ro'yxat + uzoqdan tugatish                        */
  /* ------------------------------------------------------------------ */

  /** Foydalanuvchining tugatilmagan sessiyalari (joriy sessiya belgilangan). */
  async listSessions(userId: string, currentSid?: string) {
    const sessions = await this.prisma.userSession.findMany({
      where: { userId, revokedAt: null },
      orderBy: { lastSeenAt: 'desc' },
    });
    return sessions.map((s) => ({
      id: s.id,
      deviceModel: s.deviceModel,
      platform: s.platform,
      ipAddress: s.ipAddress,
      city: s.city,
      country: s.country,
      createdAt: s.createdAt.toISOString(),
      lastSeenAt: s.lastSeenAt.toISOString(),
      isCurrent: s.id === currentSid,
    }));
  }

  /** Bitta sessiyani tugatish (egalik tekshiriladi). */
  async revokeSession(
    userId: string,
    sessionId: string,
  ): Promise<{ ok: true }> {
    const result = await this.prisma.userSession.updateMany({
      where: { id: sessionId, userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    if (result.count === 0) {
      throw new NotFoundException('Sessiya topilmadi');
    }
    return { ok: true };
  }

  /** Joriydan boshqa BARCHA sessiyalarni tugatish. */
  async revokeOtherSessions(
    userId: string,
    currentSid?: string,
  ): Promise<{ count: number }> {
    const result = await this.prisma.userSession.updateMany({
      where: {
        userId,
        revokedAt: null,
        ...(currentSid && { id: { not: currentSid } }),
      },
      data: { revokedAt: new Date() },
    });
    return { count: result.count };
  }
}
