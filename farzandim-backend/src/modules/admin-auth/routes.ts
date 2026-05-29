import { FastifyPluginAsync, type FastifyReply, type FastifyRequest } from 'fastify';
import { z } from 'zod';
import { prisma } from '../../lib/prisma';
import { hashPassword, verifyPassword } from './password';
import {
  signAdminAccessToken,
  signAdminRefreshToken,
  verifyAdminRefreshToken,
} from './jwt';
import { staffAuthGuard } from '../../middleware/staff-auth';
import {
  findMatchingBackupCode,
  generateBackupCodes,
  generateSecret,
  hashBackupCodes,
  signChallenge,
  verifyChallenge,
  verifyTotpCode,
} from '../../lib/two-factor';
import { logAudit } from '../../lib/audit-log';

const LoginBody = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1),
});

const RefreshBody = z.object({
  refresh_token: z.string().min(1).optional(),
  refreshToken: z.string().min(1).optional(),
});

const VerifyBody = z.object({
  challengeId: z.string().min(1),
  code: z.string().min(6).max(10),
});

const EnableBody = z.object({
  code: z.string().min(6).max(8),
});

const DisableBody = z.object({
  password: z.string().min(1),
  code: z.string().min(6).max(10).optional(),
});

const ChangePasswordBody = z.object({
  current_password: z.string().min(1).optional(),
  currentPassword: z.string().min(1).optional(),
  new_password: z.string().min(8).max(120).optional(),
  newPassword: z.string().min(8).max(120).optional(),
});

function profileOf(staff: {
  id: string;
  email: string;
  name: string;
  phone: string | null;
  moderatorRoleKey: string;
  permissions: string[];
  status: string;
  lastActivityAt: Date | null;
  twoFactorEnabled: boolean;
}) {
  const isFullAccess = staff.moderatorRoleKey === 'super_admin';
  return {
    id: staff.id,
    email: staff.email,
    name: staff.name,
    phone: staff.phone,
    role: staff.moderatorRoleKey,
    moderatorRoleKey: staff.moderatorRoleKey,
    permissions: isFullAccess ? [] : staff.permissions,
    isFullAccess,
    status: staff.status,
    lastActivityAt: staff.lastActivityAt?.toISOString() ?? null,
    twoFactorEnabled: staff.twoFactorEnabled,
  };
}

function pickRefresh(body: z.infer<typeof RefreshBody>): string | null {
  return body.refresh_token ?? body.refreshToken ?? null;
}

// H7 — refresh token HttpOnly cookie. Brauzerdagi XSS uni o'qiy olmaydi.
const REFRESH_COOKIE = 'admin_refresh';
const REFRESH_COOKIE_PATH = '/api/admin/auth';
const REFRESH_COOKIE_MAX_AGE = 30 * 24 * 60 * 60; // 30 kun (ADMIN_JWT_REFRESH_EXPIRES bilan mos)

/** Origin header — brauzerda doimo bor (POST'da ham), native client'da yo'q. */
function isBrowser(request: FastifyRequest): boolean {
  return Boolean(request.headers.origin);
}

function setRefreshCookie(reply: FastifyReply, token: string): void {
  reply.setCookie(REFRESH_COOKIE, token, {
    httpOnly: true,
    secure: true,
    sameSite: 'none',
    path: REFRESH_COOKIE_PATH,
    maxAge: REFRESH_COOKIE_MAX_AGE,
  });
}

function clearRefreshCookie(reply: FastifyReply): void {
  reply.clearCookie(REFRESH_COOKIE, { path: REFRESH_COOKIE_PATH });
}

// Sprint 5.x — strict per-route rate limit (brute-force prevention).
// 15 daqiqada 8 ta urinish: shu vaqt ichida 9-urinish 429 qaytaradi.
const STRICT_AUTH_LIMIT = {
  config: {
    rateLimit: {
      max: 8,
      timeWindow: '15 minutes',
    },
  },
} as const;

// /refresh va /change-password biroz yumshoqroq — har vaqt ichida ko'proq urinish
const MODERATE_AUTH_LIMIT = {
  config: {
    rateLimit: {
      max: 30,
      timeWindow: '1 minute',
    },
  },
} as const;

export const adminAuthRoutes: FastifyPluginAsync = async (fastify) => {
  /**
   * POST /api/admin/auth/login
   * email + password → access + refresh JWT.
   * Rate limit: 8 urinish / 15 daq / IP (brute-force himoyasi).
   */
  fastify.post('/login', STRICT_AUTH_LIMIT, async (request, reply) => {
    const parsed = LoginBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid login payload' });
    }
    const { email, password } = parsed.data;
    const staff = await prisma.moderator.findUnique({ where: { email } });
    if (!staff) {
      void logAudit(request, { action: 'auth.login.failure', email, status: 'failure', details: { reason: 'unknown_email' } });
      return reply.code(401).send({ error: 'Invalid email or password' });
    }
    if (staff.status === 'blocked') {
      void logAudit(request, { action: 'auth.login.failure', moderatorId: staff.id, email, status: 'failure', details: { reason: 'blocked' } });
      return reply.code(403).send({ error: 'Account blocked' });
    }
    const ok = await verifyPassword(password, staff.passwordHash);
    if (!ok) {
      void logAudit(request, { action: 'auth.login.failure', moderatorId: staff.id, email, status: 'failure', details: { reason: 'wrong_password' } });
      return reply.code(401).send({ error: 'Invalid email or password' });
    }

    // 2FA gating: password OK, lekin admin 2FA yoqilgan bo'lsa, full
    // token o'rniga challenge token qaytaramiz. Frontend 6-raqamli kod
    // bilan /2fa/verify ga so'rov yuboradi.
    if (staff.twoFactorEnabled) {
      const challengeId = signChallenge(staff.id);
      void logAudit(request, { action: 'auth.login.2fa_required', moderatorId: staff.id, email });
      return reply.send({
        requires2fa: true,
        challengeId,
        // maskedPhone — TOTP'da kerak emas, lekin Flutter UI kontrakti uchun
        // bo'sh string qaytaramiz (Flutter UI app nomini ko'rsatadi).
        maskedPhone: '',
      });
    }

    const updated = await prisma.moderator.update({
      where: { id: staff.id },
      data: { lastActivityAt: new Date() },
    });

    const claims = {
      sub: updated.id,
      email: updated.email,
      role: updated.moderatorRoleKey,
      tokenVersion: updated.tokenVersion,
    };
    const accessToken = signAdminAccessToken(claims);
    const refreshToken = signAdminRefreshToken(claims);

    void logAudit(request, { action: 'auth.login.success', moderatorId: updated.id, email: updated.email });

    // H7 — brauzer: refresh token HttpOnly cookie'da, body'da yuborilmaydi.
    // Native client: cookie'siz, body orqali (oldingidek).
    if (isBrowser(request)) {
      setRefreshCookie(reply, refreshToken);
      return reply.send({
        access_token: accessToken,
        accessToken,
        user: profileOf(updated),
      });
    }
    return reply.send({
      access_token: accessToken,
      accessToken,
      refresh_token: refreshToken,
      refreshToken,
      user: profileOf(updated),
    });
  });

  /**
   * POST /api/admin/auth/2fa/verify
   * Login challenge tokenni va 6-raqamli TOTP kod (yoki backup kod) bilan
   * tasdiqlash → full access+refresh JWT.
   * Rate limit: 8 urinish / 15 daq / IP.
   */
  fastify.post('/2fa/verify', STRICT_AUTH_LIMIT, async (request, reply) => {
    const parsed = VerifyBody.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid 2FA payload' });
    }
    const { challengeId, code } = parsed.data;
    const challenge = verifyChallenge(challengeId);
    if (!challenge) {
      return reply.code(401).send({ error: 'Challenge expired or invalid' });
    }
    const staff = await prisma.moderator.findUnique({ where: { id: challenge.sub } });
    if (!staff || staff.status === 'blocked' || !staff.twoFactorEnabled || !staff.twoFactorSecret) {
      return reply.code(401).send({ error: 'Session invalid' });
    }

    let codeOk = verifyTotpCode(code, staff.twoFactorSecret);
    let usedBackupIndex = -1;
    if (!codeOk) {
      usedBackupIndex = await findMatchingBackupCode(code, staff.twoFactorBackupCodes);
      if (usedBackupIndex >= 0) codeOk = true;
    }
    if (!codeOk) {
      void logAudit(request, { action: 'auth.2fa.verify.failure', moderatorId: staff.id, email: staff.email, status: 'failure' });
      return reply.code(401).send({ error: 'Invalid 2FA code' });
    }

    // Backup kod ishlatilgan bo'lsa, uni ro'yxatdan o'chirish (single-use).
    const nextBackupCodes =
      usedBackupIndex >= 0
        ? staff.twoFactorBackupCodes.filter((_, i) => i !== usedBackupIndex)
        : staff.twoFactorBackupCodes;

    const updated = await prisma.moderator.update({
      where: { id: staff.id },
      data: {
        lastActivityAt: new Date(),
        twoFactorBackupCodes: nextBackupCodes,
      },
    });

    const claims = {
      sub: updated.id,
      email: updated.email,
      role: updated.moderatorRoleKey,
      tokenVersion: updated.tokenVersion,
    };
    const accessToken = signAdminAccessToken(claims);
    const refreshToken = signAdminRefreshToken(claims);

    void logAudit(request, {
      action: usedBackupIndex >= 0 ? 'auth.2fa.verify.backup_code' : 'auth.2fa.verify.success',
      moderatorId: updated.id,
      email: updated.email,
      details: { remainingBackupCodes: nextBackupCodes.length },
    });

    // H7 — brauzer: refresh token HttpOnly cookie'da; native: body orqali.
    if (isBrowser(request)) {
      setRefreshCookie(reply, refreshToken);
      return reply.send({
        access_token: accessToken,
        accessToken,
        user: profileOf(updated),
        usedBackupCode: usedBackupIndex >= 0,
        remainingBackupCodes: nextBackupCodes.length,
      });
    }
    return reply.send({
      access_token: accessToken,
      accessToken,
      refresh_token: refreshToken,
      refreshToken,
      user: profileOf(updated),
      usedBackupCode: usedBackupIndex >= 0,
      remainingBackupCodes: nextBackupCodes.length,
    });
  });

  /**
   * GET /api/admin/auth/2fa/status
   * Joriy admin 2FA holatini qaytaradi.
   */
  fastify.get('/2fa/status', { preHandler: staffAuthGuard }, async (request, reply) => {
    const sub = request.staff?.sub;
    if (!sub) return reply.code(401).send({ error: 'Unauthorized' });
    const staff = await prisma.moderator.findUnique({ where: { id: sub } });
    if (!staff) return reply.code(404).send({ error: 'Staff not found' });
    return reply.send({
      enabled: staff.twoFactorEnabled,
      enabledAt: staff.twoFactorEnabledAt?.toISOString() ?? null,
      remainingBackupCodes: staff.twoFactorBackupCodes.length,
    });
  });

  /**
   * POST /api/admin/auth/2fa/setup
   * Yangi TOTP secret + otpauth URI qaytaradi. Hali enable qilinmaydi.
   * Foydalanuvchi QR code'ni skanlab, /2fa/enable ga verifik kod yuboradi.
   *
   * Eslatma: Secret bu safar plaintext ko'rsatiladi. Foydalanuvchi sahifani
   * yangilab/yopib qo'ysa, qaytadan setup chaqirilishi kerak.
   */
  fastify.post('/2fa/setup', { preHandler: staffAuthGuard }, async (request, reply) => {
    const sub = request.staff?.sub;
    if (!sub) return reply.code(401).send({ error: 'Unauthorized' });
    const staff = await prisma.moderator.findUnique({ where: { id: sub } });
    if (!staff) return reply.code(404).send({ error: 'Staff not found' });
    if (staff.twoFactorEnabled) {
      return reply.code(409).send({ error: '2FA already enabled. Disable first.' });
    }
    const { secret, otpauthUri } = generateSecret(staff.email);

    // Hozircha DB'ga yozamiz (lekin enabled=false). /2fa/enable ga muvaffaqiyatli
    // kod kelganda enabled=true qilinadi. Bu yondashuv eski yarim-sozlangan
    // sessiyalarni avtomat tozalaydi (har setup secret'ni qayta yozadi).
    await prisma.moderator.update({
      where: { id: staff.id },
      data: { twoFactorSecret: secret },
    });

    return reply.send({
      secret,
      otpauthUri,
      qrInstruction:
        'Authenticator app (Google Authenticator, Authy, 1Password)\'da QR code skanlang yoki secret\'ni qo\'lda kiriting.',
    });
  });

  /**
   * POST /api/admin/auth/2fa/enable
   * Setup'dan keyin: foydalanuvchi app'dan 6-raqamli kodni kiritadi, biz
   * tekshiramiz, to'g'ri bo'lsa enable + backup codes generatsiya qilamiz.
   */
  fastify.post('/2fa/enable', { preHandler: staffAuthGuard }, async (request, reply) => {
    const sub = request.staff?.sub;
    if (!sub) return reply.code(401).send({ error: 'Unauthorized' });
    const parsed = EnableBody.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Invalid payload' });
    const staff = await prisma.moderator.findUnique({ where: { id: sub } });
    if (!staff) return reply.code(404).send({ error: 'Staff not found' });
    if (staff.twoFactorEnabled) {
      return reply.code(409).send({ error: '2FA already enabled' });
    }
    if (!staff.twoFactorSecret) {
      return reply.code(400).send({ error: 'Run /2fa/setup first' });
    }
    if (!verifyTotpCode(parsed.data.code, staff.twoFactorSecret)) {
      return reply.code(401).send({ error: 'Invalid verification code' });
    }

    const plaintextBackupCodes = generateBackupCodes(8);
    const hashedBackupCodes = await hashBackupCodes(plaintextBackupCodes);

    await prisma.moderator.update({
      where: { id: staff.id },
      data: {
        twoFactorEnabled: true,
        twoFactorEnabledAt: new Date(),
        twoFactorBackupCodes: hashedBackupCodes,
      },
    });

    void logAudit(request, { action: 'auth.2fa.enable', moderatorId: staff.id, email: staff.email });

    // Backup kodlar faqat shu safar plaintext qaytariladi.
    return reply.send({
      enabled: true,
      backupCodes: plaintextBackupCodes,
      warning: 'Backup kodlarni xavfsiz joyga saqlang. Bular faqat hozir ko\'rsatiladi.',
    });
  });

  /**
   * POST /api/admin/auth/2fa/disable
   * 2FA o'chirish — password + (agar enabled bo'lsa) TOTP kod talab qilinadi.
   */
  fastify.post('/2fa/disable', { preHandler: staffAuthGuard }, async (request, reply) => {
    const sub = request.staff?.sub;
    if (!sub) return reply.code(401).send({ error: 'Unauthorized' });
    const parsed = DisableBody.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'Invalid payload' });
    const staff = await prisma.moderator.findUnique({ where: { id: sub } });
    if (!staff) return reply.code(404).send({ error: 'Staff not found' });

    const passwordOk = await verifyPassword(parsed.data.password, staff.passwordHash);
    if (!passwordOk) return reply.code(401).send({ error: 'Invalid password' });

    if (staff.twoFactorEnabled && staff.twoFactorSecret) {
      const code = parsed.data.code;
      if (!code) {
        return reply.code(400).send({ error: 'TOTP code required to disable 2FA' });
      }
      let codeOk = verifyTotpCode(code, staff.twoFactorSecret);
      if (!codeOk) {
        const backupIdx = await findMatchingBackupCode(code, staff.twoFactorBackupCodes);
        if (backupIdx >= 0) codeOk = true;
      }
      if (!codeOk) return reply.code(401).send({ error: 'Invalid 2FA code' });
    }

    await prisma.moderator.update({
      where: { id: staff.id },
      data: {
        twoFactorEnabled: false,
        twoFactorSecret: null,
        twoFactorEnabledAt: null,
        twoFactorBackupCodes: [],
      },
    });

    void logAudit(request, { action: 'auth.2fa.disable', moderatorId: staff.id, email: staff.email });

    return reply.send({ disabled: true });
  });

  /**
   * POST /api/admin/auth/refresh
   * Rate limit: 30 / daq / IP.
   */
  fastify.post('/refresh', MODERATE_AUTH_LIMIT, async (request, reply) => {
    const parsed = RefreshBody.safeParse(request.body ?? {});
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid refresh payload' });
    }
    // H7 — brauzer: HttpOnly cookie'dan; native client: body'dan.
    const token = request.cookies?.[REFRESH_COOKIE] ?? pickRefresh(parsed.data);
    if (!token) return reply.code(400).send({ error: 'Missing refresh token' });
    try {
      const payload = verifyAdminRefreshToken(token);
      const staff = await prisma.moderator.findUnique({ where: { id: payload.sub } });
      if (!staff || staff.status === 'blocked') {
        return reply.code(401).send({ error: 'Session invalid' });
      }
      // Sprint 6 P1 — logout'dan keyin tokenVersion mos kelmaydi.
      if ((payload.tokenVersion ?? 0) !== staff.tokenVersion) {
        return reply.code(401).send({ error: 'Token bekor qilingan' });
      }
      const claims = {
        sub: staff.id,
        email: staff.email,
        role: staff.moderatorRoleKey,
        tokenVersion: staff.tokenVersion,
      };
      const accessToken = signAdminAccessToken(claims);
      return reply.send({ access_token: accessToken, accessToken });
    } catch {
      return reply.code(401).send({ error: 'Refresh token expired or invalid' });
    }
  });

  /**
   * GET /api/admin/auth/staff-me
   */
  fastify.get('/staff-me', { preHandler: staffAuthGuard }, async (request, reply) => {
    const sub = request.staff?.sub;
    if (!sub) return reply.code(401).send({ error: 'Unauthorized' });
    const staff = await prisma.moderator.findUnique({ where: { id: sub } });
    if (!staff) return reply.code(404).send({ error: 'Staff not found' });
    return reply.send(profileOf(staff));
  });

  /**
   * POST /api/admin/auth/change-password
   * Currently authenticated staff updates their own password.
   * Rate limit: 30 / daq / IP.
   */
  fastify.post('/change-password', {
    ...MODERATE_AUTH_LIMIT,
    preHandler: staffAuthGuard,
  }, async (request, reply) => {
    const sub = request.staff?.sub;
    if (!sub) return reply.code(401).send({ error: 'Unauthorized' });
    const parsed = ChangePasswordBody.safeParse(request.body ?? {});
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid payload' });
    }
    const current = parsed.data.current_password ?? parsed.data.currentPassword;
    const next = parsed.data.new_password ?? parsed.data.newPassword;
    if (!current || !next) {
      return reply.code(400).send({ error: 'currentPassword and newPassword are required' });
    }
    const staff = await prisma.moderator.findUnique({ where: { id: sub } });
    if (!staff) return reply.code(404).send({ error: 'Staff not found' });
    const ok = await verifyPassword(current, staff.passwordHash);
    if (!ok) return reply.code(401).send({ error: 'Current password is incorrect' });
    await prisma.moderator.update({
      where: { id: sub },
      data: { passwordHash: await hashPassword(next) },
    });
    void logAudit(request, { action: 'auth.change_password', moderatorId: sub, email: staff.email });
    return reply.send({ ok: true });
  });

  /**
   * POST /api/admin/auth/logout
   * tokenVersion'ni increment qiladi — barcha refresh token'lar bekor bo'ladi.
   */
  fastify.post('/logout', { preHandler: staffAuthGuard }, async (request, reply) => {
    const sub = request.staff?.sub;
    if (!sub) return reply.code(401).send({ error: 'Unauthorized' });
    await prisma.moderator.update({
      where: { id: sub },
      data: { tokenVersion: { increment: 1 } },
    });
    clearRefreshCookie(reply); // H7 — refresh cookie'sini tozalash
    void logAudit(request, { action: 'auth.logout', moderatorId: sub });
    return reply.send({ ok: true });
  });
};
