// Yutuqlar (badge): ochish (idempotent, qulf ostida) va ro'yxat (+ eski ma'lumotdan
// kechiktirilgan to'ldirish). Yutuq DON / XP bermaydi.

import { Injectable } from '@nestjs/common';
import { ChildProfile, IqSessionStatus, XpEventType } from '@prisma/client';
import { PrismaService } from '../../../common/database/prisma.service';
import { hasMasteredTopic } from '../../learning/learning-mastery.query';
import { assertChildAccess } from '../child-access';
import { AWARD_TX_OPTIONS, lockChildAwards } from '../child-award-lock';
import {
  applyUnlocks,
  BADGE_IDS,
  BadgeId,
  BadgeItem,
  readAchievements,
  streakBadgesFor,
  toBadgeItems,
} from './badge-catalog';

export interface UnlockResult {
  profile: ChildProfile;
  /** Shu chaqiruvda haqiqatan yangi ochilgan yutuqlar bormi. */
  changed: boolean;
}

@Injectable()
export class BadgesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Yutuqlarni ochish. Bola qulfi ostida o'qib-yoziladi (parallel voqealar
   * bir-birining yutug'ini yo'qotmaydi). `at = null` — vaqti noma'lum (backfill).
   */
  async unlock(childId: string, ids: readonly string[], at: Date | null): Promise<UnlockResult> {
    return this.prisma.$transaction(async (tx) => {
      await lockChildAwards(tx, childId);
      const profile = await tx.childProfile.upsert({
        where: { childId },
        create: { childId },
        update: {},
      });
      const next = applyUnlocks(profile, ids, at);
      if (!next) return { profile, changed: false };
      const updated = await tx.childProfile.update({
        where: { childId },
        data: { achievements: next.achievements, achievementDates: next.dates },
      });
      return { profile: updated, changed: true };
    }, AWARD_TX_OPTIONS);
  }

  /**
   * `GET /children/:childId/badges` — katalog tartibida holat. Hali ochilmagan
   * yutuqlar mavjud ma'lumotdan tekshiriladi (idempotent backfill): vaqti noma'lum
   * (`earnedAt: null`) bo'lib ochiladi.
   */
  async list(childId: string, userId: string): Promise<{ items: BadgeItem[] }> {
    await assertChildAccess(this.prisma, childId, userId);
    const profile = await this.prisma.childProfile.upsert({
      where: { childId },
      create: { childId },
      update: {},
    });
    const earned = new Set(readAchievements(profile.achievements));
    const missing = BADGE_IDS.filter((id) => !earned.has(id));
    const found = missing.length > 0 ? await this.findEarned(childId, profile, missing) : [];
    const current = found.length > 0 ? (await this.unlock(childId, found, null)).profile : profile;
    return { items: toBadgeItems(current.achievements, current.achievementDates) };
  }

  /** Hali ochilmagan yutuqlardan mavjud ma'lumot bo'yicha allaqachon topshirilganlari. */
  private async findEarned(
    childId: string,
    profile: Pick<ChildProfile, 'streakDays'>,
    missing: readonly BadgeId[],
  ): Promise<BadgeId[]> {
    const probes: Record<Exclude<BadgeId, `streak_${number}`>, () => Promise<boolean>> = {
      first_book: async () =>
        (await this.prisma.xpEvent.findFirst({
          where: { childId, type: XpEventType.BOOK_READ },
          select: { id: true },
        })) !== null,
      olympian: async () =>
        (await this.prisma.olympiadAttempt.findFirst({
          where: { childId },
          select: { id: true },
        })) !== null,
      topic_master: () => hasMasteredTopic(this.prisma, childId, null),
      thinker: async () =>
        (await this.prisma.iqSession.findFirst({
          where: { childId, status: IqSessionStatus.COMPLETED },
          select: { id: true },
        })) !== null,
    };
    const byStreak = streakBadgesFor(profile.streakDays);
    const checked = await Promise.all(
      missing.map(async (id) => {
        if (id === 'streak_7' || id === 'streak_30') return byStreak.includes(id);
        return probes[id]();
      }),
    );
    return missing.filter((_, i) => checked[i]);
  }
}
