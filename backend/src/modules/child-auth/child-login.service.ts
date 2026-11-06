// Bola kirishi (A01–A02, A05): login + parol, birinchi kirishda parol o'rnatish, parolni almashtirish.
//
// Xavfsizlik:
//  - noto'g'ri login va noto'g'ri parol bir xil javob (401 INVALID_CREDENTIALS); mavjud bo'lmagan login
//    uchun ham bcrypt tekshiruvi bajariladi (vaqt farqi yo'q);
//  - 15 daqiqada 5 xato -> 15 daqiqaga blok (429 LOCKED, blok paytida to'g'ri parol ham o'tmaydi);
//    mavjud bo'lmagan loginlar uchun ham xotirada xuddi shu qoida ("soya" blok) — mavjudlik fosh bo'lmaydi;
//  - setupToken bir martalik (parol xeshining barmoq izi + shartli UPDATE).

import { ConflictException, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { AuditService } from '../../common/audit/audit.service';
import { PrismaService } from '../../common/database/prisma.service';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { AuthService } from '../auth/auth.service';
import { announceSessionsClosed, closeSessions } from '../auth/session-revocation';
import { ChildAuthClock } from './child-auth-clock';
import { CREDENTIAL_BCRYPT_ROUNDS, LOGIN_INPUT_MAX, LOGIN_SESSION_KIND } from './child-auth.constants';
import {
  invalidCredentials,
  lockedError,
  noCredential,
  setupTokenInvalid,
  weakPassword,
  wrongPassword,
} from './child-auth.errors';
import { checkNewPassword, isValidLogin, normalizeLogin } from './child-credentials.helpers';
import { ChildLoginAttempts } from './child-login-attempts';
import { GhostLoginLimiter, LoginFailureState, lockRemainingSeconds } from './child-login-lock';
import type { DeviceRole } from './child-device-role';
import { ChildSetupTokens } from './child-setup-token';
import { ChildSessionsService, LoginDevice } from './child-sessions.service';
import type { ChangeChildPasswordDto, ChildLoginDto, ChildSetupDto } from './dto/child-login.dto';

export interface ChildSummary {
  id: string;
  name: string;
}

export interface ChildOkBody {
  status: 'OK';
  accessToken: string;
  refreshToken: string;
  sessionId: string;
  /** MAIN — bu qurilma asosiy (nazorat shu yerda); SECONDARY — bolada asosiy qurilma bor, bu faqat akkaunt kirishi. */
  deviceRole: DeviceRole;
  child: ChildSummary;
  user: { id: string };
}

export interface ChildSetupRequiredBody {
  status: 'SETUP_REQUIRED';
  setupToken: string;
  child: ChildSummary;
}

/** Mavjud bo'lmagan login uchun ham bir xil vaqt sarflansin (bir marta hisoblanadi). */
let dummyHash: Promise<string> | undefined;
const getDummyHash = () => (dummyHash ??= bcrypt.hash('parvoz-child-dummy-password', CREDENTIAL_BCRYPT_ROUNDS));

@Injectable()
export class ChildLoginService implements OnModuleInit {
  private readonly logger = new Logger(ChildLoginService.name);
  private readonly ghost = new GhostLoginLimiter();

  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
    private readonly sessions: ChildSessionsService,
    private readonly attempts: ChildLoginAttempts,
    private readonly setupTokens: ChildSetupTokens,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
    private readonly clock: ChildAuthClock,
  ) {}

  onModuleInit(): void {
    // Soxta xeshni oldindan hisoblab qo'yamiz: birinchi "noma'lum login" so'rovi sekinroq bo'lib qolmasin.
    void getDummyHash();
  }

  async login(dto: ChildLoginDto): Promise<ChildOkBody | ChildSetupRequiredBody> {
    const now = this.clock.now();
    const login = normalizeLogin(dto.login).slice(0, LOGIN_INPUT_MAX);
    const cred = isValidLogin(login)
      ? await this.prisma.childCredential.findUnique({
          where: { login },
          include: { child: { select: { id: true, name: true } } },
        })
      : null;

    const locked = cred ? lockRemainingSeconds(cred, now) : this.ghost.lockRemainingSeconds(login, now);
    if (locked > 0) throw lockedError(locked);

    const matches = await bcrypt.compare(dto.password, cred?.passwordHash ?? (await getDummyHash()));
    if (!cred || !matches) throw await this.failedAttempt(cred?.childId ?? null, login, now);

    const { mustChangePassword } = await this.attempts.recordSuccess(cred.childId, cred.passwordHash, now);
    if (mustChangePassword) {
      return {
        status: 'SETUP_REQUIRED',
        setupToken: this.setupTokens.sign(cred.childId, cred.passwordHash),
        child: toSummary(cred.child),
      };
    }
    return this.completeLogin(cred.child, dto.device);
  }

  /** Birinchi kirish: vaqtinchalik parol o'rniga o'z parolini o'rnatadi va kiradi. */
  async setup(dto: ChildSetupDto): Promise<ChildOkBody> {
    const now = this.clock.now();
    const claims = this.setupTokens.verify(dto.setupToken);
    if (!claims) throw setupTokenInvalid();
    const cred = await this.prisma.childCredential.findUnique({
      where: { childId: claims.childId },
      include: { child: { select: { id: true, name: true } } },
    });
    if (
      !cred ||
      !cred.mustChangePassword ||
      this.setupTokens.fingerprint(cred.passwordHash) !== claims.fingerprint
    ) {
      throw setupTokenInvalid();
    }

    const issue = checkNewPassword(dto.newPassword, cred.login);
    if (issue) throw weakPassword(issue);
    if (await bcrypt.compare(dto.newPassword, cred.passwordHash)) throw weakPassword('SAME_AS_CURRENT');

    const passwordHash = await bcrypt.hash(dto.newPassword, CREDENTIAL_BCRYPT_ROUNDS);
    // Bir martalik: shartli almashtirish — parallel so'rovlardan faqat bittasi yutadi.
    const swapped = await this.prisma.childCredential.updateMany({
      where: { childId: cred.childId, passwordHash: cred.passwordHash, mustChangePassword: true },
      data: {
        passwordHash,
        mustChangePassword: false,
        passwordChangedAt: now,
        lastLoginAt: now,
        failedLogins: 0,
        failedWindowStartedAt: null,
        lockedUntil: null,
      },
    });
    if (swapped.count === 0) throw setupTokenInvalid();
    return this.completeLogin(cred.child, dto.device);
  }

  /** `POST /auth/child/password`: joriy parol bilan tasdiqlab almashtiradi; boshqa LOGIN sessiyalar yopiladi. */
  async changePassword(user: JwtPayload, dto: ChangeChildPasswordDto): Promise<void> {
    const now = this.clock.now();
    const child = await this.prisma.child.findUnique({
      where: { childUserId: user.userId },
      select: { id: true, credential: true },
    });
    const cred = child?.credential;
    if (!child || !cred) throw noCredential();

    const locked = lockRemainingSeconds(cred, now);
    if (locked > 0) throw lockedError(locked);
    if (!(await bcrypt.compare(dto.currentPassword, cred.passwordHash))) {
      const { state } = await this.attempts.recordFailure(child.id, now);
      const remaining = lockRemainingSeconds(state, now);
      throw remaining > 0 ? lockedError(remaining) : wrongPassword();
    }

    const issue = checkNewPassword(dto.newPassword, cred.login);
    if (issue) throw weakPassword(issue);
    if (dto.newPassword === dto.currentPassword) throw weakPassword('SAME_AS_CURRENT');

    const passwordHash = await bcrypt.hash(dto.newPassword, CREDENTIAL_BCRYPT_ROUNDS);
    const swapped = await this.prisma.childCredential.updateMany({
      where: { childId: child.id, passwordHash: cred.passwordHash },
      data: {
        passwordHash,
        mustChangePassword: false,
        passwordChangedAt: now,
        failedLogins: 0,
        failedWindowStartedAt: null,
        lockedUntil: null,
      },
    });
    if (swapped.count === 0) {
      throw new ConflictException({ code: 'PASSWORD_CHANGED', message: 'Credentials were changed meanwhile' });
    }

    const closed = await closeSessions(
      this.prisma,
      user.userId,
      'SIGNED_OUT',
      { kind: LOGIN_SESSION_KIND, ...(user.sid && { id: { not: user.sid } }) },
      now,
    );
    announceSessionsClosed(this.realtime, user.userId, closed, 'SIGNED_OUT');
    await this.audit.log(user.userId, 'auth', 'CHILD_PASSWORD_CHANGE', child.id, { closedSessions: closed.length });
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /** Xato urinishni qayd etadi va qaytariladigan xatoni tanlaydi (blok bo'lsa 429, aks holda 401). */
  private async failedAttempt(childId: string | null, login: string, now: Date): Promise<Error> {
    let state: LoginFailureState;
    if (childId) {
      const result = await this.attempts.recordFailure(childId, now);
      state = result.state;
      if (result.justLocked) {
        // Blok boshlanishi — bitta audit yozuvi (login va IP yo'q).
        await this.audit.log(null, 'auth', 'CHILD_LOGIN_LOCKED', childId, { lockedSeconds: lockRemainingSeconds(state, now) });
        this.logger.warn('bola logini vaqtincha bloklandi');
      }
    } else {
      state = this.ghost.recordFailure(login, now);
    }
    const remaining = lockRemainingSeconds(state, now);
    return remaining > 0 ? lockedError(remaining) : invalidCredentials();
  }

  /** Sessiya ochadi va token beradi (IP / User-Agent auditga yozilmaydi — bola ma'lumoti). */
  private async completeLogin(child: ChildSummary, device: LoginDevice): Promise<ChildOkBody> {
    const opened = await this.sessions.open(child.id, device, this.clock.now());
    const tokens = this.auth.issueSessionTokens(
      { userId: opened.user.id, role: 'CHILD', tokenVersion: opened.user.tokenVersion, sid: opened.sessionId },
      opened.rjti,
    );
    await this.audit.log(opened.user.id, 'auth', 'CHILD_LOGIN', child.id, {
      method: 'credentials',
      platform: device.platform,
    });
    return {
      status: 'OK',
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      sessionId: opened.sessionId,
      deviceRole: opened.deviceRole,
      child: toSummary(child),
      user: { id: opened.user.id },
    };
  }
}

const toSummary = (child: ChildSummary): ChildSummary => ({ id: child.id, name: child.name });
