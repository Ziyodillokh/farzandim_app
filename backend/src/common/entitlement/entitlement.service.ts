import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import {
  DEFAULT_TIER,
  TIER_FEATURES,
  TIER_MAX_CHILDREN,
  TIER_MAX_PARENTS,
} from './entitlement.constants';

export interface Entitlement {
  /** free | standard | premium | vip */
  tier: string;
  /** Yoqilgan funksiya kalitlari (plan.features yoki daraja preseti). */
  features: string[];
  /** Ulanadigan maksimal bola soni. */
  maxChildren: number;
  /** Bir oilaga ulanadigan maksimal ota-ona (co-parent) soni. */
  maxParents: number;
  /** Joriy tarif 1-haftalik Standart demo (trial) orqali kelganmi. */
  isTrial: boolean;
  /** Trial tugash vaqti (ISO) — banner "X kun qoldi" uchun. Trial bo'lmasa null. */
  trialEndsAt: string | null;
}

/**
 * Foydalanuvchining tarifi (entitlement) — AKTIV obunaga qarab. Butun backend
 * feature-gating shu servisdan foydalanadi (yagona manba). Obuna yo'q/tugagan
 * bo'lsa `free`.
 */
@Injectable()
export class EntitlementService {
  constructor(private readonly prisma: PrismaService) {}

  async getEntitlement(userId: string): Promise<Entitlement> {
    const sub = await this.prisma.subscription.findFirst({
      where: {
        userId,
        status: 'ACTIVE',
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      orderBy: { expiresAt: 'desc' },
      include: { plan: true },
    });

    const tier = sub?.plan?.entitlementTier ?? DEFAULT_TIER;
    // Admin plan.features'ni tanlagan bo'lsa — AYNAN o'sha (aniq nazorat);
    // bo'sh bo'lsa daraja preseti.
    const planFeatures = sub?.plan?.features ?? [];
    const features =
      planFeatures.length > 0
        ? planFeatures
        : (TIER_FEATURES[tier] ?? TIER_FEATURES[DEFAULT_TIER]);
    const maxChildren =
      TIER_MAX_CHILDREN[tier] ?? TIER_MAX_CHILDREN[DEFAULT_TIER];
    const maxParents =
      TIER_MAX_PARENTS[tier] ?? TIER_MAX_PARENTS[DEFAULT_TIER];

    // Trial holati — ilova bannerni ("Standart demo — X kun qoldi") shu bilan
    // ko'rsatadi. Faqat trial obuna aktiv bo'lsa `trialEndsAt` beriladi.
    const isTrial = sub?.isTrial ?? false;
    const trialEndsAt =
      isTrial && sub?.expiresAt ? sub.expiresAt.toISOString() : null;

    return { tier, features, maxChildren, maxParents, isTrial, trialEndsAt };
  }

  /** Foydalanuvchida shu funksiya yoqilganmi. */
  async hasFeature(userId: string, feature: string): Promise<boolean> {
    const ent = await this.getEntitlement(userId);
    return ent.features.includes(feature);
  }
}
