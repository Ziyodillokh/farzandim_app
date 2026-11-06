// Bola LOGIN sessiyalari (credential bilan kirish): bola foydalanuvchisini topish / yaratish, bir qurilmaga
// bitta sessiya, bir foydalanuvchida ko'pi bilan 3 ta faol sessiya (eng eskisi yopiladi), qurilmalar ro'yxati.
// Sessiyalar umumiy `UserSession` jadvalida (`kind = 'LOGIN'`); yangilash tokeni aylanishi mavjud
// `AuthService.refreshToken` orqali ishlaydi (token `sid` + `rjti` bilan).

import { Injectable, Logger } from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../common/database/prisma.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { announceSessionsClosed, closeSessions } from '../auth/session-revocation';
import { LOGIN_SESSION_KIND, MAX_LOGIN_SESSIONS } from './child-auth.constants';
import { childNotFound } from './child-auth.errors';
import type { ChildPlatform } from './dto/child-device.dto';

export interface LoginDevice {
  id: string;
  model?: string;
  platform: ChildPlatform;
}

export interface OpenedSession {
  user: Pick<User, 'id' | 'tokenVersion'>;
  sessionId: string;
  /** Yangilash tokeni aylanishi uchun boshlang'ich `jti`. */
  rjti: string;
}

export interface DeviceView {
  sessionId: string | null;
  model: string | null;
  platform: string | null;
  lastSeenAt: string | null;
  current: boolean;
  paired: boolean;
}

type Tx = Prisma.TransactionClient;

const userSelect = { id: true, tokenVersion: true, isActive: true, role: true } as const;

@Injectable()
export class ChildSessionsService {
  private readonly logger = new Logger(ChildSessionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
  ) {}

  /**
   * LOGIN sessiyasini ochadi. Bola foydalanuvchisi (`Child.childUserId`) faol bo'lsa o'sha — juftlangan
   * qurilma ishlashda davom etadi; aks holda yangisi yaratilib `childUserId` ga yoziladi.
   * Bir qurilmadagi eski sessiya almashtiriladi (`SIGNED_OUT`), 3 tadan oshsa eng eskisi yopiladi
   * (`SIGNED_IN_ELSEWHERE`). Yopilganlarga WebSocket `session:closed` tranzaksiyadan keyin ketadi.
   */
  async open(childId: string, device: LoginDevice, now: Date): Promise<OpenedSession> {
    const opened = await this.prisma.$transaction(async (tx) => {
      const user = await this.ensureChildUser(tx, childId);
      // Bir foydalanuvchining parallel kirishlari navbat bilan (sessiya soni aniq hisoblansin).
      await tx.$queryRaw`SELECT id FROM users WHERE id = ${user.id} FOR UPDATE`;

      const sameDevice = await closeSessions(
        tx,
        user.id,
        'SIGNED_OUT',
        { kind: LOGIN_SESSION_KIND, deviceId: device.id },
        now,
      );
      const active = await tx.userSession.findMany({
        where: { userId: user.id, kind: LOGIN_SESSION_KIND, revokedAt: null },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        select: { id: true },
      });
      const overflow = Math.max(0, active.length - (MAX_LOGIN_SESSIONS - 1));
      const evictIds = active.slice(0, overflow).map((s) => s.id);
      const evicted =
        evictIds.length > 0
          ? await closeSessions(tx, user.id, 'SIGNED_IN_ELSEWHERE', { id: { in: evictIds } }, now)
          : [];

      const rjti = randomUUID();
      const session = await tx.userSession.create({
        data: {
          userId: user.id,
          jti: rjti,
          kind: LOGIN_SESSION_KIND,
          deviceId: device.id,
          deviceModel: device.model?.trim() || null,
          platform: device.platform,
          lastSeenAt: now,
          // Bola IP / User-Agent saqlanmaydi (ma'lumot minimallashtirish); geo-qidiruv ham yo'q.
        },
        select: { id: true },
      });
      return { user, sessionId: session.id, rjti, sameDevice, evicted };
    });

    announceSessionsClosed(this.realtime, opened.user.id, opened.sameDevice, 'SIGNED_OUT');
    announceSessionsClosed(this.realtime, opened.user.id, opened.evicted, 'SIGNED_IN_ELSEWHERE');
    return { user: opened.user, sessionId: opened.sessionId, rjti: opened.rjti };
  }

  /**
   * Joriy qurilmalar: LOGIN sessiyalari + (bor bo'lsa) ota-ona juftlagan qurilma
   * (`sessionId: null`, `paired: true`). `current` — so'rov shu sessiyadan (juftlangan: `sid`siz token).
   */
  async devices(userId: string, currentSid: string | undefined): Promise<DeviceView[]> {
    const [child, sessions] = await Promise.all([
      this.prisma.child.findUnique({
        where: { childUserId: userId },
        select: { pairedAt: true, deviceModel: true, androidVersion: true, lastSeenAt: true },
      }),
      this.prisma.userSession.findMany({
        where: { userId, kind: LOGIN_SESSION_KIND, revokedAt: null },
        orderBy: [{ lastSeenAt: 'desc' }, { id: 'asc' }],
      }),
    ]);
    const items: DeviceView[] = sessions.map((s) => ({
      sessionId: s.id,
      model: s.deviceModel,
      platform: s.platform,
      lastSeenAt: s.lastSeenAt.toISOString(),
      current: s.id === currentSid,
      paired: false,
    }));
    if (child?.pairedAt) {
      items.push({
        sessionId: null,
        model: child.deviceModel,
        platform: child.androidVersion ? 'android' : null,
        lastSeenAt: child.lastSeenAt?.toISOString() ?? null,
        current: !currentSid,
        paired: true,
      });
    }
    return items;
  }

  /** Faol bola foydalanuvchisi; yo'q yoki nofaol bo'lsa yangisi yaratilib bola profiliga bog'lanadi. */
  private async ensureChildUser(tx: Tx, childId: string) {
    await tx.$queryRaw`SELECT id FROM children WHERE id = ${childId} FOR UPDATE`;
    const child = await tx.child.findUnique({
      where: { id: childId },
      select: { id: true, name: true, childUser: { select: userSelect } },
    });
    if (!child) throw childNotFound();
    const existing = child.childUser;
    if (existing && existing.isActive && existing.role === 'CHILD') return existing;

    const user = await tx.user.create({ data: { role: 'CHILD', name: child.name }, select: userSelect });
    await tx.child.update({ where: { id: childId }, data: { childUserId: user.id } });
    this.logger.log('bola foydalanuvchisi yaratildi (credential kirish)');
    return user;
  }
}
