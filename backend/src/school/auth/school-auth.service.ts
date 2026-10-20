// ─────────────────────────────────────────────────────────────────────
// Maktab paneli kirishi: maktab kodi + login + parol (+ TOTP), sessiyalar
// (refresh rotatsiyasi, o'g'irlangan token qayta ishlatilsa sessiya yopiladi;
// bir vaqtdagi parallel refresh uchun qisqa imtiyoz oynasi), hisobni
// vaqtincha bloklash, parol almashtirish, 2FA.
// ─────────────────────────────────────────────────────────────────────

import {
  HttpException,
  HttpStatus,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { SchoolStaff, SchoolStaffSession } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import * as speakeasy from 'speakeasy';
import { z } from 'zod';
import { PrismaService } from '../../common/database/prisma.service';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid } from '../common/school-errors';
import { msg, parseOrThrow } from '../common/school-zod';
import { SCHOOL_ROLES } from './permissions';
import { SchoolActor } from './school-actor';
import {
  SCHOOL_ACCESS_TTL_SECONDS,
  SCHOOL_REFRESH_TTL_MS,
  SchoolTokensService,
} from './school-tokens.service';

/** Ketma-ket xato kirishlar va blok muddati. */
export const MAX_FAILED_LOGINS = 5;
export const LOCK_MINUTES = 15;
export const MIN_PASSWORD_LENGTH = 10;
/**
 * Aylantirilgan (oldingi) refresh sir shu muddat ichida qabul qilinadi:
 * ikki tab yoki takroriy effekt bir vaqtda refresh qilsa, yutqazgani
 * o'g'irlik deb hisoblanmaydi — u faqat access token oladi (cookie'siz).
 */
export const REFRESH_GRACE_MS = 30_000;
const BCRYPT_ROUNDS = 12;
/** Mavjud bo'lmagan login uchun ham bir xil vaqt sarflansin (bir marta hisoblanadi). */
let dummyHash: Promise<string> | undefined;
const getDummyHash = () => (dummyHash ??= bcrypt.hash('parvoz-dummy-password', BCRYPT_ROUNDS));

export const loginSchema = z.object({
  school: z.string().trim().toLowerCase().min(2, msg.required).max(40),
  username: z.string().trim().toLowerCase().min(1, msg.required).max(40),
  password: z.string().min(1, msg.required).max(200),
  totp: z.string().trim().regex(/^\d{6}$/).optional(),
});

const passwordChangeSchema = z
  .object({
    current: z.string().min(1, msg.required),
    next: z.string().min(MIN_PASSWORD_LENGTH, msg.tooShort).max(200, msg.tooLong),
  })
  .refine((v) => v.current !== v.next, { path: ['next'], message: msg.required });

export interface SessionMeta {
  ip?: string;
  userAgent?: string;
}

export interface SchoolMe {
  staff: {
    id: string;
    fullName: string;
    role: SchoolStaff['role'];
    position: string;
    phone: string;
    email: string;
    username: string | null;
    photo: string | null;
    portrait: string | null;
  };
  school: { id: string; code: string; name: string; shortName: string; logo: string | null };
  scope: 'SCHOOL' | 'OWN_CLASS';
  classIds: string[];
  permissions: string[];
  mustChangePassword: boolean;
  totpEnabled: boolean;
}

export interface IssuedSession {
  accessToken: string;
  expiresIn: number;
  /** Cookie qiymati: `<sessiyaId>.<sir>` (imtiyoz yo'lida yo'q — cookie o'zgarmaydi). */
  refreshToken?: string;
  me: SchoolMe;
}

@Injectable()
export class SchoolAuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: SchoolTokensService,
    private readonly audit: SchoolAuditService,
  ) {}

  async login(input: unknown, meta: SessionMeta): Promise<IssuedSession> {
    const data = parseOrThrow(loginSchema, input);
    const school = await this.prisma.school.findUnique({ where: { code: data.school } });
    const staff = school
      ? await this.prisma.schoolStaff.findUnique({
          where: { schoolId_username: { schoolId: school.id, username: data.username } },
        })
      : null;

    if (staff?.lockedUntil && staff.lockedUntil > new Date()) {
      throw new HttpException(
        {
          code: 'LOCKED',
          message: 'Too many failed attempts',
          retryAfterSeconds: Math.ceil((staff.lockedUntil.getTime() - Date.now()) / 1000),
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const passwordOk = await bcrypt.compare(
      data.password,
      staff?.passwordHash ?? (await getDummyHash()),
    );
    if (!school || !staff || !staff.passwordHash || !passwordOk || !staff.active || school.status !== 'ACTIVE') {
      if (staff) await this.recordFailure(staff);
      throw new UnauthorizedException({ code: 'INVALID_CREDENTIALS', message: 'Invalid credentials' });
    }
    if (staff.totpEnabled) {
      if (!data.totp) {
        throw new UnauthorizedException({ code: 'TOTP_REQUIRED', message: 'Two-factor code required' });
      }
      if (!verifyTotp(staff.totpSecret, data.totp)) {
        await this.recordFailure(staff);
        throw new UnauthorizedException({ code: 'TOTP_INVALID', message: 'Invalid two-factor code' });
      }
    }

    await this.prisma.schoolStaff.update({
      where: { id: staff.id },
      data: { failedLogins: 0, lockedUntil: null, lastLoginAt: new Date() },
    });
    const issued = await this.issue(staff.id, meta);
    await this.audit.write(this.actorOf(issued.me, meta), {
      module: 'AUTH',
      action: 'auth.login',
      summary: 'Panelga kirdi',
    });
    return issued;
  }

  /**
   * Refresh rotatsiyasi. Oldingi sir faqat imtiyoz oynasida (parallel so'rov)
   * qabul qilinadi; undan keyin yoki eskiroq sir — o'g'irlik: sessiya yopiladi.
   */
  async refresh(cookie: string | undefined, meta: SessionMeta): Promise<IssuedSession> {
    const [sessionId, secret] = (cookie ?? '').split('.');
    if (!sessionId || !secret) throw sessionExpired();
    const session = await this.liveSession(sessionId);
    if (!session) throw sessionExpired();
    if (!this.tokens.matches(secret, session.tokenHash)) return this.refreshInGrace(session, secret);
    await this.assertStaffActive(session.staffId);

    const next = this.tokens.newRefreshSecret();
    const now = new Date();
    // Shartli yangilash: parallel refresh'dan faqat bittasi aylantiradi.
    const rotated = await this.prisma.schoolStaffSession.updateMany({
      where: { id: sessionId, tokenHash: session.tokenHash, revokedAt: null },
      data: {
        tokenHash: next.hash,
        previousTokenHash: session.tokenHash,
        rotatedAt: now,
        lastUsedAt: now,
        expiresAt: new Date(now.getTime() + SCHOOL_REFRESH_TTL_MS),
        ip: meta.ip ?? session.ip,
        userAgent: meta.userAgent?.slice(0, 300) ?? session.userAgent,
      },
    });
    if (rotated.count === 1) return this.build(session.staffId, sessionId, next.secret);

    // Parallel so'rov bizdan oldin aylantirdi — endi bizning sir "oldingi".
    const latest = await this.liveSession(sessionId);
    if (!latest) throw sessionExpired();
    return this.refreshInGrace(latest, secret);
  }

  async logout(cookie: string | undefined, actor?: SchoolActor): Promise<void> {
    const sessionId = actor?.sessionId ?? (cookie ?? '').split('.')[0];
    if (!sessionId) return;
    await this.prisma.schoolStaffSession.updateMany({
      where: { id: sessionId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async me(actor: SchoolActor): Promise<SchoolMe> {
    return this.meOf(actor.staffId);
  }

  /** Parol almashtirish — boshqa barcha sessiyalar yopiladi. */
  async changePassword(actor: SchoolActor, input: unknown): Promise<void> {
    const data = parseOrThrow(passwordChangeSchema, input);
    const staff = await this.prisma.schoolStaff.findUniqueOrThrow({ where: { id: actor.staffId } });
    if (!staff.passwordHash || !(await bcrypt.compare(data.current, staff.passwordHash))) {
      throw invalid('current: errors.auth.wrongPassword');
    }
    await this.prisma.$transaction([
      this.prisma.schoolStaff.update({
        where: { id: actor.staffId },
        data: {
          passwordHash: await bcrypt.hash(data.next, BCRYPT_ROUNDS),
          mustChangePassword: false,
        },
      }),
      this.prisma.schoolStaffSession.updateMany({
        where: { staffId: actor.staffId, id: { not: actor.sessionId }, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
    await this.audit.write(actor, {
      module: 'AUTH',
      action: 'auth.passwordChange',
      summary: 'Parol almashtirildi',
    });
  }

  /** 2FA sozlash: yangi sir (hali yoqilmagan). */
  async setupTotp(actor: SchoolActor): Promise<{ secret: string; otpauthUrl: string }> {
    const staff = await this.prisma.schoolStaff.findUniqueOrThrow({
      where: { id: actor.staffId },
      include: { school: { select: { code: true } } },
    });
    if (staff.totpEnabled) throw conflict('totp already enabled');
    const secret = speakeasy.generateSecret({ length: 20 });
    await this.prisma.schoolStaff.update({
      where: { id: staff.id },
      data: { totpSecret: secret.base32 },
    });
    const otpauthUrl = speakeasy.otpauthURL({
      secret: secret.base32,
      encoding: 'base32',
      label: `${staff.school.code}:${staff.username ?? staff.id}`,
      issuer: 'Parvoz School',
    });
    return { secret: secret.base32, otpauthUrl };
  }

  async enableTotp(actor: SchoolActor, code: unknown): Promise<void> {
    const staff = await this.prisma.schoolStaff.findUniqueOrThrow({ where: { id: actor.staffId } });
    if (staff.totpEnabled) throw conflict('totp already enabled');
    if (typeof code !== 'string' || !verifyTotp(staff.totpSecret, code)) {
      throw invalid('code: errors.auth.totpInvalid');
    }
    await this.prisma.schoolStaff.update({ where: { id: staff.id }, data: { totpEnabled: true } });
    await this.audit.write(actor, { module: 'AUTH', action: 'auth.totpEnable', summary: '2FA yoqildi' });
  }

  async disableTotp(actor: SchoolActor, password: unknown): Promise<void> {
    const staff = await this.prisma.schoolStaff.findUniqueOrThrow({ where: { id: actor.staffId } });
    if (
      typeof password !== 'string' ||
      !staff.passwordHash ||
      !(await bcrypt.compare(password, staff.passwordHash))
    ) {
      throw invalid('password: errors.auth.wrongPassword');
    }
    await this.prisma.schoolStaff.update({
      where: { id: staff.id },
      data: { totpEnabled: false, totpSecret: null },
    });
    await this.audit.write(actor, { module: 'AUTH', action: 'auth.totpDisable', summary: '2FA o\'chirildi' });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  private async liveSession(id: string): Promise<SchoolStaffSession | null> {
    const session = await this.prisma.schoolStaffSession.findUnique({ where: { id } });
    return session && !session.revokedAt && session.expiresAt > new Date() ? session : null;
  }

  /** Oldingi sir imtiyoz oynasida — access token (cookie o'zgarmaydi), aks holda sessiya yopiladi. */
  private async refreshInGrace(session: SchoolStaffSession, secret: string): Promise<IssuedSession> {
    const inGrace =
      session.previousTokenHash !== null &&
      session.rotatedAt !== null &&
      Date.now() - session.rotatedAt.getTime() <= REFRESH_GRACE_MS &&
      this.tokens.matches(secret, session.previousTokenHash);
    if (!inGrace) {
      await this.prisma.schoolStaffSession.updateMany({
        where: { id: session.id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw sessionExpired();
    }
    await this.assertStaffActive(session.staffId);
    return this.build(session.staffId, session.id);
  }

  private async assertStaffActive(staffId: string): Promise<void> {
    const staff = await this.prisma.schoolStaff.findUnique({
      where: { id: staffId },
      include: { school: { select: { status: true } } },
    });
    if (!staff || !staff.active || staff.school.status !== 'ACTIVE') throw sessionExpired();
  }

  /** Atomik hisob: parallel noto'g'ri urinishlar ham bloklashga yetadi (eski qiymatdan yozilmaydi). */
  private async recordFailure(staff: SchoolStaff): Promise<void> {
    const { failedLogins } = await this.prisma.schoolStaff.update({
      where: { id: staff.id },
      data: { failedLogins: { increment: 1 } },
      select: { failedLogins: true },
    });
    if (failedLogins < MAX_FAILED_LOGINS) return;
    await this.prisma.schoolStaff.updateMany({
      where: { id: staff.id, failedLogins: { gte: MAX_FAILED_LOGINS } },
      data: { failedLogins: 0, lockedUntil: new Date(Date.now() + LOCK_MINUTES * 60_000) },
    });
  }

  private async issue(staffId: string, meta: SessionMeta): Promise<IssuedSession> {
    const staff = await this.prisma.schoolStaff.findUniqueOrThrow({ where: { id: staffId } });
    const refresh = this.tokens.newRefreshSecret();
    const session = await this.prisma.schoolStaffSession.create({
      data: {
        schoolId: staff.schoolId,
        staffId,
        tokenHash: refresh.hash,
        ip: meta.ip,
        userAgent: meta.userAgent?.slice(0, 300),
        expiresAt: new Date(Date.now() + SCHOOL_REFRESH_TTL_MS),
      },
    });
    return this.build(staffId, session.id, refresh.secret);
  }

  private async build(staffId: string, sessionId: string, secret?: string): Promise<IssuedSession> {
    const me = await this.meOf(staffId);
    const staff = await this.prisma.schoolStaff.findUniqueOrThrow({
      where: { id: staffId },
      select: { tokenVersion: true, schoolId: true },
    });
    return {
      accessToken: this.tokens.signAccess({
        sub: staffId,
        sch: staff.schoolId,
        sid: sessionId,
        tv: staff.tokenVersion,
      }),
      expiresIn: SCHOOL_ACCESS_TTL_SECONDS,
      refreshToken: secret ? `${sessionId}.${secret}` : undefined,
      me,
    };
  }

  private async meOf(staffId: string): Promise<SchoolMe> {
    const staff = await this.prisma.schoolStaff.findUniqueOrThrow({
      where: { id: staffId },
      include: {
        classes: { select: { classId: true } },
        school: { select: { id: true, code: true, name: true, shortName: true, logo: true } },
      },
    });
    const role = SCHOOL_ROLES[staff.role];
    return {
      staff: {
        id: staff.id,
        fullName: staff.fullName,
        role: staff.role,
        position: staff.position,
        phone: staff.phone,
        email: staff.email,
        username: staff.username,
        photo: staff.photo,
        portrait: staff.portrait,
      },
      school: staff.school,
      scope: role.scope,
      classIds: role.scope === 'SCHOOL' ? [] : staff.classes.map((c) => c.classId),
      permissions: [...role.permissions],
      mustChangePassword: staff.mustChangePassword,
      totpEnabled: staff.totpEnabled,
    };
  }

  private actorOf(me: SchoolMe, meta: SessionMeta): SchoolActor {
    return {
      staffId: me.staff.id,
      schoolId: me.school.id,
      sessionId: '',
      name: me.staff.fullName,
      role: me.staff.role,
      scope: me.scope,
      classIds: me.classIds,
      ip: meta.ip,
    };
  }
}

/** Parolni xeshlash (xodim hisobini yaratish / tiklashda). */
export function hashStaffPassword(password: string): Promise<string> {
  return bcrypt.hash(password, BCRYPT_ROUNDS);
}

function verifyTotp(secret: string | null, token: string): boolean {
  if (!secret) return false;
  return speakeasy.totp.verify({ secret, encoding: 'base32', token, window: 1 });
}

function sessionExpired(): UnauthorizedException {
  return new UnauthorizedException({ code: 'SESSION_EXPIRED', message: 'Session expired' });
}

