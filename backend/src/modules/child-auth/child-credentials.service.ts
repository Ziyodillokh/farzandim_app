// Bola kirish maʼlumotlarini berish / qayta tiklash (ota-ona yoki maktab).
//
// Birinchi berish: login yaratiladi (so'ralgan yoki taklif qilingan), vaqtinchalik parol FAQAT javobda
// qaytadi (bcrypt xeshi saqlanadi, parol hech qayerda yozilmaydi va loglanmaydi). Mavjud bo'lsa — qayta
// tiklash: yangi vaqtinchalik parol, blok / xatolar tozalanadi, ochiq tiklash so'rovlari RESTORED bo'ladi va
// (standart) bolaning barcha qurilmalari chiqariladi (`signOutDevices`): sessiyalar RECOVERED sababi bilan
// yopiladi, tokenVersion oshadi (eski, sid'siz juftlangan qurilma ham chiqadi), push tokenlari o'chadi.

import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ChildCredential, Prisma } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { AuditService } from '../../common/audit/audit.service';
import { PrismaService } from '../../common/database/prisma.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { announceSessionsClosed, closeSessions } from '../auth/session-revocation';
import { ChildAuthClock } from './child-auth-clock';
import {
  CHILD_UNPAIRED_EVENT,
  childRecoveryNotificationId,
  CREDENTIAL_BCRYPT_ROUNDS,
} from './child-auth.constants';
import { childNotFound, loginTaken } from './child-auth.errors';
import { findOwnedChild } from './child-ownership';
import {
  generateTemporaryPassword,
  isValidLogin,
  normalizeLogin,
  splitChildName,
  suggestLoginCandidates,
} from './child-credentials.helpers';
import type { IssueChildCredentialDto } from './dto/issue-child-credential.dto';

type Tx = Prisma.TransactionClient;

export type CredentialActor =
  | { kind: 'PARENT'; userId: string }
  | { kind: 'SCHOOL'; staffId: string };

export interface CredentialView {
  login: string;
  issuedBy: ChildCredential['issuedBy'];
  issuedAt: string;
  mustChangePassword: boolean;
  lastLoginAt: string | null;
}

export interface IssuedCredential {
  login: string;
  temporaryPassword: string;
  issuedAt: string;
}

export interface IssueOutcome extends IssuedCredential {
  reset: boolean;
  signedOutDevices: boolean;
  closedSessions: number;
  resolvedRequests: number;
}

export function toCredentialView(c: ChildCredential): CredentialView {
  return {
    login: c.login,
    issuedBy: c.issuedBy,
    issuedAt: c.issuedAt.toISOString(),
    mustChangePassword: c.mustChangePassword,
    lastLoginAt: c.lastLoginAt?.toISOString() ?? null,
  };
}

@Injectable()
export class ChildCredentialsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
    private readonly audit: AuditService,
    private readonly clock: ChildAuthClock,
  ) {}

  /** Bola uchun joriy kirish maʼlumotlari (parolsiz) yoki `null`. */
  async view(childId: string): Promise<CredentialView | null> {
    const row = await this.prisma.childCredential.findUnique({ where: { childId } });
    return row ? toCredentialView(row) : null;
  }

  // ── Ota-ona ────────────────────────────────────────────────────────

  async viewForParent(parentId: string, childId: string): Promise<CredentialView | null> {
    await findOwnedChild(this.prisma, parentId, childId);
    return this.view(childId);
  }

  async issueForParent(
    parentId: string,
    childId: string,
    dto: IssueChildCredentialDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ): Promise<IssuedCredential> {
    const child = await findOwnedChild(this.prisma, parentId, childId);
    const outcome = await this.issueOrReset({
      childId,
      actor: { kind: 'PARENT', userId: parentId },
      login: dto.login,
      signOutDevices: dto.signOutDevices ?? true,
      names: splitChildName(child.name),
    });
    // Audit: parol va login YO'Q (faqat amal va oqibatlari).
    await this.audit.log(
      parentId,
      'child',
      outcome.reset ? 'CREDENTIAL_RESET' : 'CREDENTIAL_ISSUE',
      childId,
      {
        signedOutDevices: outcome.signedOutDevices,
        closedSessions: outcome.closedSessions,
        resolvedRequests: outcome.resolvedRequests,
      },
      reqMeta,
    );
    return { login: outcome.login, temporaryPassword: outcome.temporaryPassword, issuedAt: outcome.issuedAt };
  }

  // ── Umumiy yadro (ota-ona + maktab) ────────────────────────────────

  async issueOrReset(input: {
    childId: string;
    actor: CredentialActor;
    login?: string;
    signOutDevices: boolean;
    names: { firstName?: string; lastName?: string };
  }): Promise<IssueOutcome> {
    const now = this.clock.now();
    const temporaryPassword = generateTemporaryPassword();
    // Xeshlash tranzaksiyadan tashqarida: qator qulfi 250 ms+ ushlanib qolmasin.
    const passwordHash = await bcrypt.hash(temporaryPassword, CREDENTIAL_BCRYPT_ROUNDS);

    const done = await this.prisma.$transaction(async (tx) => {
      // Bir bolaning parallel berish / tiklashlari shu qatorda navbatga turadi.
      await tx.$queryRaw`SELECT id FROM children WHERE id = ${input.childId} FOR UPDATE`;
      const child = await tx.child.findUnique({
        where: { id: input.childId },
        select: { id: true, childUserId: true },
      });
      if (!child) throw childNotFound();

      const existing = await tx.childCredential.findUnique({ where: { childId: input.childId } });
      const fields = issuedFields(input.actor, passwordHash, now);
      const login = existing
        ? (await tx.childCredential.update({ where: { childId: input.childId }, data: fields })).login
        : await this.create(tx, input.childId, fields, input.login, input.names);

      // Sessiyalarni chiqarish faqat QAYTA TIKLASHDA (birinchi berishda mavjud qurilmalar tegilmaydi).
      const signOut = existing !== null && input.signOutDevices && child.childUserId !== null;
      const resolvedRequests = await this.resolveRecoveryRequests(tx, input.childId, signOut, now);
      let closed: string[] = [];
      if (signOut && child.childUserId) {
        closed = await closeSessions(tx, child.childUserId, 'RECOVERED', {}, now);
        // tokenVersion: eski (sid'siz) juftlangan qurilmaning yangilash tokeni ham yaroqsiz bo'ladi.
        await tx.user.update({ where: { id: child.childUserId }, data: { tokenVersion: { increment: 1 } } });
        // Chiqarilgan (yo'qolgan bo'lishi mumkin) qurilmaga push ketmasin.
        await tx.fcmToken.deleteMany({ where: { userId: child.childUserId } });
      }
      return { login, reset: existing !== null, signOut, closed, resolvedRequests, childUserId: child.childUserId };
    });

    if (done.signOut && done.childUserId) {
      announceSessionsClosed(this.realtime, done.childUserId, done.closed, 'RECOVERED', true);
      this.emitUnpaired(done.childUserId, input.childId, now);
    }
    return {
      login: done.login,
      temporaryPassword,
      issuedAt: now.toISOString(),
      reset: done.reset,
      signedOutDevices: done.signOut,
      closedSessions: done.closed.length,
      resolvedRequests: done.resolvedRequests,
    };
  }

  // ── Ichki ──────────────────────────────────────────────────────────

  /**
   * Yangi credential. Login: so'ralgan (yaroqli va bo'sh bo'lsa), yaroqsiz bo'lsa taklif qilinganlardan
   * birinchi bo'shi; so'ralgan yaroqli login band bo'lsa 409 LOGIN_TAKEN. Loginlar yagonaligi global
   * advisory lock bilan kafolatlanadi (berish kam uchraydi, navbat arzimaydi).
   */
  private async create(
    tx: Tx,
    childId: string,
    fields: ReturnType<typeof issuedFields>,
    requestedLogin: string | undefined,
    names: { firstName?: string; lastName?: string },
  ): Promise<string> {
    await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended('child-credential-login', 0))`;
    const requested = normalizeLogin(requestedLogin);
    let login: string | undefined;
    if (requested && isValidLogin(requested)) {
      if (await tx.childCredential.findUnique({ where: { login: requested }, select: { childId: true } })) {
        throw loginTaken();
      }
      login = requested;
    } else {
      const candidates = suggestLoginCandidates(names);
      const taken = await tx.childCredential.findMany({
        where: { login: { in: candidates } },
        select: { login: true },
      });
      const takenSet = new Set(taken.map((t) => t.login));
      login = candidates.find((c) => !takenSet.has(c));
    }
    if (!login) throw new ServiceUnavailableException({ code: 'LOGIN_UNAVAILABLE', message: 'Could not allocate a login' });
    await tx.childCredential.create({ data: { childId, login, ...fields } });
    return login;
  }

  /** Ochiq (RECEIVED) tiklash so'rovlari yechiladi; ularga bog'liq xodim bildirishnomalari olib tashlanadi. */
  private async resolveRecoveryRequests(tx: Tx, childId: string, signedOut: boolean, now: Date): Promise<number> {
    const open = await tx.childRecoveryRequest.findMany({
      where: { childId, status: 'RECEIVED' },
      select: { id: true },
    });
    if (open.length === 0) return 0;
    const ids = open.map((r) => r.id);
    await tx.childRecoveryRequest.updateMany({
      where: { id: { in: ids }, status: 'RECEIVED' },
      data: { status: 'RESTORED', restoredAt: now, signedOutAt: signedOut ? now : null },
    });
    await tx.schoolStaffNotification.deleteMany({ where: { id: { in: ids.map(childRecoveryNotificationId) } } });
    return ids.length;
  }

  /** Eski (juftlangan) bola ilovasi `child:unpaired` ni mahalliy uzish sifatida qabul qiladi. */
  private emitUnpaired(childUserId: string, childId: string, at: Date): void {
    try {
      this.realtime.emitToUser(childUserId, CHILD_UNPAIRED_EVENT, {
        childId,
        reason: 'RECOVERED',
        at: at.toISOString(),
      });
    } catch {
      // WebSocket best-effort.
    }
  }
}

function issuedFields(actor: CredentialActor, passwordHash: string, now: Date) {
  return {
    passwordHash,
    mustChangePassword: true,
    failedLogins: 0,
    failedWindowStartedAt: null,
    lockedUntil: null,
    issuedBy: actor.kind,
    issuedByUserId: actor.kind === 'PARENT' ? actor.userId : null,
    issuedByStaffId: actor.kind === 'SCHOOL' ? actor.staffId : null,
    issuedAt: now,
  } satisfies Omit<Prisma.ChildCredentialUncheckedCreateInput, 'childId' | 'login'>;
}
