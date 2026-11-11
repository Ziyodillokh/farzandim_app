import {
  ForbiddenException,
  GoneException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ListenSession } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { FcmService } from '../../common/fcm/fcm.service';

/**
 * ListenSessionsService — ota-ona bola atrofidagi ovozni JONLI eshitishi.
 *
 * ⚠️ OVOZ HECH QAYERDA SAQLANMAYDI. Bu servis faqat sessiya HAYOT SIKLINI
 * boshqaradi (boshlash, ulanish, to'xtatish) va WebRTC signallarini (SDP,
 * ICE) ikki telefon o'rtasida uzatadi. Ovozning O'ZI bola→ota-ona
 * to'g'ridan-to'g'ri (P2P) o'tadi va serverga tegmaydi.
 *
 * Qonuniylik: bola qurilmasida "Ota-onangiz tinglamoqda" indikatori doim
 * ko'rinadi (foreground service) va bola istalgan payt to'xtata oladi.
 *
 * ⛔ 2026-11-11 dan funksiya OLIB TASHLANDI (egasi qarori): yangi sessiya
 * boshlanmaydi (`410 FEATURE_REMOVED`), bola uyg'otilmaydi. To'xtatish, tarix
 * va eskirgan sessiyalarni yopish eski yozuvlar uchun qoladi.
 */
@Injectable()
export class ListenSessionsService {
  private readonly logger = new Logger(ListenSessionsService.name);

  /** Bola qurilmasi shuncha vaqtda ulanmasa sessiya EXPIRED bo'ladi. */
  private static readonly CONNECT_TTL_MS = 45_000;

  /** Xavfsizlik chegarasi: jonli sessiya maksimal shuncha davom etadi. */
  private static readonly MAX_ACTIVE_MS = 30 * 60 * 1000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
    private readonly fcm: FcmService,
    private readonly audit: AuditService,
  ) {}

  private serialize(s: ListenSession) {
    return {
      id: s.id,
      childId: s.childId,
      status: s.status,
      startedAt: s.startedAt.toISOString(),
      endedAt: s.endedAt ? s.endedAt.toISOString() : null,
      endedBy: s.endedBy,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  Ota-ona eshitishni BOSHLAYDI                                       */
  /* ------------------------------------------------------------------ */
  async start(
    _childId: string,
    _userId: string,
    _request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ): Promise<never> {
    // Eski Parvoz Parents versiyalari tugmani hali ko'rsatadi — aniq javob beriladi.
    throw new GoneException({ code: 'FEATURE_REMOVED', message: 'Live listening has been removed' });
  }

  /* ------------------------------------------------------------------ */
  /*  To'xtatish — ota-ona YOKI bola                                     */
  /* ------------------------------------------------------------------ */
  async end(
    sessionId: string,
    userId: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const session = await this.prisma.listenSession.findUnique({
      where: { id: sessionId },
      include: { child: true },
    });
    if (!session) throw new NotFoundException('Session not found');

    const isParent = session.parentId === userId;
    const isChild = session.child.childUserId === userId;
    if (!isParent && !isChild) throw new ForbiddenException('Forbidden');

    if (session.status === 'ENDED' || session.status === 'EXPIRED') {
      return this.serialize(session);
    }

    const endedBy = isChild ? 'child' : 'parent';
    const updated = await this.prisma.listenSession.update({
      where: { id: sessionId },
      data: { status: 'ENDED', endedAt: new Date(), endedBy },
    });

    await this.audit.log(userId, 'listen_session', 'END', sessionId, { endedBy }, request);

    // Ikkala tomonga ham — mikrofonni o'chir, ekranni yop.
    this.realtime.emitToUser(session.parentId, 'listen:ended', { id: sessionId, endedBy });
    if (session.child.childUserId) {
      this.realtime.emitToUser(session.child.childUserId, 'listen:ended', {
        id: sessionId,
        endedBy,
      });
    }
    return this.serialize(updated);
  }

  /* ------------------------------------------------------------------ */
  /*  Audit ro'yxati — ota-ona (ovozsiz, faqat metadata)                 */
  /* ------------------------------------------------------------------ */
  async list(childId: string, userId: string, limit = 50) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    const sessions = await this.prisma.listenSession.findMany({
      where: { childId },
      orderBy: { startedAt: 'desc' },
      take: Math.min(limit, 200),
    });
    return { sessions: sessions.map((s) => this.serialize(s)), count: sessions.length };
  }

  /* ------------------------------------------------------------------ */
  /*  Cron — osilib qolgan sessiyalarni tugatadi                         */
  /* ------------------------------------------------------------------ */
  @Cron('30 */1 * * * *', { name: 'listen-sessions-expire' })
  async expireStale(): Promise<void> {
    const now = new Date();

    // Bola ulanmagan PENDING'lar → EXPIRED.
    const expired = await this.prisma.listenSession.updateMany({
      where: { status: 'PENDING', expiresAt: { lt: now } },
      data: { status: 'EXPIRED', endedAt: now, endedBy: 'timeout' },
    });

    // Xavfsizlik chegarasidan oshgan ACTIVE'lar → ENDED (mikrofon uzoq
    // qolib ketmasin).
    const cutoff = new Date(now.getTime() - ListenSessionsService.MAX_ACTIVE_MS);
    const capped = await this.prisma.listenSession.findMany({
      where: { status: 'ACTIVE', startedAt: { lt: cutoff } },
      include: { child: { select: { childUserId: true } } },
    });
    for (const s of capped) {
      await this.prisma.listenSession.update({
        where: { id: s.id },
        data: { status: 'ENDED', endedAt: now, endedBy: 'timeout' },
      });
      this.realtime.emitToUser(s.parentId, 'listen:ended', { id: s.id, endedBy: 'timeout' });
      if (s.child.childUserId) {
        this.realtime.emitToUser(s.child.childUserId, 'listen:ended', {
          id: s.id,
          endedBy: 'timeout',
        });
      }
    }

    if (expired.count > 0 || capped.length > 0) {
      this.logger.log(`listen expire: ${expired.count} pending, ${capped.length} capped`);
    }
  }
}
