import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import {
  levelForXp,
  statusForXp,
  calculateNewStreak,
} from '../../common/helpers/gamification-rules';
import {
  CreateXpEventDto,
  MAX_XP_DELTA,
  XpEventType,
} from './dto/create-xp-event.dto';
import { ListXpEventsDto } from './dto/list-xp-events.dto';

@Injectable()
export class GamificationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
  ) {}

  private async getOrCreateProfile(childId: string) {
    const existing = await this.prisma.childProfile.findUnique({
      where: { childId },
    });
    if (existing) return existing;
    return this.prisma.childProfile.create({ data: { childId } });
  }

  private async validateChildAccess(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    return child;
  }

  async getProfile(childId: string, userId: string) {
    await this.validateChildAccess(childId, userId);
    return this.getOrCreateProfile(childId);
  }

  async createXpEvent(
    childId: string,
    userId: string,
    dto: CreateXpEventDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    await this.validateChildAccess(childId, userId);

    // Server-side XP validation
    const maxDelta = MAX_XP_DELTA[dto.type as XpEventType];
    if (Math.abs(dto.xpDelta) > maxDelta) {
      throw new BadRequestException(
        `xpDelta for ${dto.type} must not exceed ${maxDelta} (got ${dto.xpDelta})`,
      );
    }

    const profile = await this.getOrCreateProfile(childId);
    const { newStreak } = calculateNewStreak(
      profile.lastActivityDate,
      profile.streakDays,
    );

    const donDelta = dto.donDelta ?? 0;
    const newXp = profile.xp + dto.xpDelta;
    const newDon = profile.donBalance + donDelta;
    const newLevel = levelForXp(newXp);
    const newStatus = statusForXp(newXp);

    const [event, updatedProfile] = await this.prisma.$transaction([
      this.prisma.xpEvent.create({
        data: {
          childId,
          type: dto.type,
          xpDelta: dto.xpDelta,
          donDelta,
          relatedId: dto.relatedId,
          source: dto.source as object | undefined,
        },
      }),
      this.prisma.childProfile.update({
        where: { childId },
        data: {
          xp: newXp,
          donBalance: newDon,
          level: newLevel,
          status: newStatus,
          streakDays: newStreak,
          lastActivityDate: new Date(),
        },
      }),
    ]);

    await this.audit.log(userId, 'xp_event', 'CREATE', event.id, dto, request);
    this.realtime.emitToChild(childId, 'profile:updated', updatedProfile);

    return { event, profile: updatedProfile };
  }

  /**
   * TIZIM tomonidan XP berish (egalik tekshiruvisiz) — bola olympiad/testni
   * tugatganda avtomatik chaqiriladi. Idempotent: bitta `relatedId`
   * (masalan attemptId) uchun bir martagina beriladi (qayta yuborilsa XP
   * ikki marta qo'shilmaydi).
   */
  async awardXp(
    childId: string,
    opts: {
      type: XpEventType;
      xpDelta: number;
      relatedId?: string;
      donDelta?: number;
    },
  ): Promise<void> {
    if (opts.xpDelta <= 0) return;
    if (opts.relatedId) {
      const existing = await this.prisma.xpEvent.findFirst({
        where: { childId, type: opts.type, relatedId: opts.relatedId },
        select: { id: true },
      });
      if (existing) return; // allaqachon berilgan — qayta bermaymiz
    }

    const profile = await this.getOrCreateProfile(childId);
    const { newStreak } = calculateNewStreak(
      profile.lastActivityDate,
      profile.streakDays,
    );
    const donDelta = opts.donDelta ?? 0;
    const newXp = profile.xp + opts.xpDelta;
    const newDon = profile.donBalance + donDelta;
    const newLevel = levelForXp(newXp);
    const newStatus = statusForXp(newXp);

    const [, updatedProfile] = await this.prisma.$transaction([
      this.prisma.xpEvent.create({
        data: {
          childId,
          type: opts.type,
          xpDelta: opts.xpDelta,
          donDelta,
          relatedId: opts.relatedId,
        },
      }),
      this.prisma.childProfile.update({
        where: { childId },
        data: {
          xp: newXp,
          donBalance: newDon,
          level: newLevel,
          status: newStatus,
          streakDays: newStreak,
          lastActivityDate: new Date(),
        },
      }),
    ]);

    this.realtime.emitToChild(childId, 'profile:updated', updatedProfile);
  }

  async listXpEvents(
    childId: string,
    userId: string,
    query: ListXpEventsDto,
  ) {
    await this.validateChildAccess(childId, userId);

    const { type, limit } = query;
    const events = await this.prisma.xpEvent.findMany({
      where: { childId, ...(type && { type }) },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return { events, count: events.length };
  }
}
