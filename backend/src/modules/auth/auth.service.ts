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
import { FcmService } from '../../common/fcm/fcm.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
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
import { LoginDto } from './dto/login.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import {
  hashPassword,
  verifyPassword,
} from '../../admin/admin-auth/helpers/password';
import { randomUUID } from 'crypto';
import {
  ReqMeta,
  extractClientIp,
  resolveGeo,
} from '../../common/helpers/geo-ip';

const PAIR_REQUEST_TTL_MIN = 5;

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

  async sendRegisterOtp(phone: string): Promise<{ ok: true }> {
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

    await this.audit.log(
      user.id,
      'auth',
      existing ? 'LOGIN' : 'CREATE',
      user.id,
      { telegramId, method: 'telegram' },
      reqMeta,
    );

    const { sid, rjti } = await this.createSession(
      user.id,
      { deviceModel: dto.deviceModel, platform: dto.platform ?? 'web' },
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

    // OTP'ni ishlatib bo'ldik — DB'dan tozalab qo'yamiz (replay attack
    // himoyasi: bir tasdiqlash bilan bir necha akkaunt yaratish mumkin
    // bo'lmasligi uchun). Phone'siz registration uchun no-op.
    if (phone) {
      await this.prisma.otpCode
        .deleteMany({ where: { phone } })
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
      // Refresh token reuse detection: eski rjti bilan kelsa — sessiyani
      // tugatamiz (o'g'irlangan token belgisi).
      if (payload.rjti && session.jti !== payload.rjti) {
        await this.prisma.userSession.update({
          where: { id: session.id },
          data: { revokedAt: new Date() },
        });
        throw new UnauthorizedException('Session revoked');
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

    // Re-pair flow: child already paired => need parent confirmation
    if (child.childUserId) {
      // Expire any pending pair requests
      await this.prisma.childPairRequest.updateMany({
        where: {
          childId: child.id,
          status: 'PENDING',
          expiresAt: { gt: new Date() },
        },
        data: { status: 'EXPIRED', decidedAt: new Date() },
      });

      const expiresAt = new Date(Date.now() + PAIR_REQUEST_TTL_MIN * 60 * 1000);

      const pairRequest = await this.prisma.childPairRequest.create({
        data: {
          childId: child.id,
          deviceInfo: (dto.deviceInfo as object) ?? undefined,
          ipAddress: reqMeta?.ip ?? null,
          userAgent:
            (reqMeta?.headers?.['user-agent'] as string | undefined) ?? null,
          expiresAt,
        },
      });

      await this.audit.log(
        null,
        'auth',
        'PAIR',
        pairRequest.id,
        {
          action: 'PAIR_REQUEST_CREATED',
          childId: child.id,
          familyCode: dto.familyCode,
        },
        reqMeta,
      );

      // Realtime + push to parent
      this.realtime.emitToUser(child.parentId, 'pair_request:created', {
        id: pairRequest.id,
        childId: child.id,
        childName: child.name,
        deviceInfo: pairRequest.deviceInfo,
        ipAddress: pairRequest.ipAddress,
        expiresAt: pairRequest.expiresAt.toISOString(),
      });

      try {
        await this.fcm.sendPushToUser(child.parentId, {
          title: `${child.name} — yangi qurilma`,
          body: 'Yangi qurilma family code bilan ulanmoqchi. Tasdiqlang.',
          data: {
            type: 'pair_request',
            pairRequestId: pairRequest.id,
            childId: child.id,
          },
        });
      } catch (err) {
        this.logger.warn(
          { err, pairRequestId: pairRequest.id },
          'pair_request push failed',
        );
      }

      throw new ConflictException({
        error: 'AWAITING_PARENT_CONFIRM',
        message:
          'Bola allaqachon ulangan. Ota-onangiz yangi qurilmani tasdiqlashi kerak.',
        pairRequestId: pairRequest.id,
        expiresAt: pairRequest.expiresAt.toISOString(),
        pollIntervalSec: 3,
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
