/**
 * Sprint 5.2: seed default plans, demo promocodes, and a few synthetic
 * payments anchored to real users. Idempotent — re-running won't duplicate
 * plans/promocodes.
 *
 * Usage on server:
 *   tsx prisma/seed-monetization.ts
 */
import 'dotenv/config';
import { prisma } from '../src/lib/prisma';

interface PlanSeed {
  slug: string;
  name: string;
  description: string;
  priceUzs: number;
  period: 'free' | 'monthly' | 'yearly';
  entitlementTier: 'free' | 'standard' | 'premium';
  badge: string | null;
  features: string[];
  sortOrder: number;
}

const PLANS: PlanSeed[] = [
  {
    slug: 'bepul',
    name: 'Bepul tarif',
    description: "Asosiy funksiyalar — cheklangan kontent, reklamali.",
    priceUzs: 0,
    period: 'free',
    entitlementTier: 'free',
    badge: null,
    features: ['screen_time', 'geolocation'],
    sortOrder: 1,
  },
  {
    slug: 'oylik',
    name: 'Oylik tarif',
    description: "To'liq kontent kirish, audiokitoblar va konkurslarda ishtirok.",
    priceUzs: 29_000,
    period: 'monthly',
    entitlementTier: 'standard',
    badge: 'Mashhur',
    features: ['full_access', 'audiobooks', 'contests', 'no_ads', 'screen_time', 'video'],
    sortOrder: 2,
  },
  {
    slug: 'yillik',
    name: 'Yillik tarif',
    description: "Eng yaxshi taklif — yillik to'lov bilan chegirma + premium analytics.",
    priceUzs: 290_000,
    period: 'yearly',
    entitlementTier: 'premium',
    badge: 'Eng yaxshi taklif',
    features: [
      'full_access',
      'audiobooks',
      'contests',
      'no_ads',
      'geolocation',
      'screen_time',
      'premium_analytics',
      'chat',
      'video',
      'xp',
    ],
    sortOrder: 3,
  },
];

interface PromocodeSeed {
  code: string;
  discountPct: number;
  usageLimit: number;
  usedCount: number;
  status: 'active' | 'inactive' | 'archived';
  expiresInDays: number;
  planSlug: string | null;
}

const PROMOS: PromocodeSeed[] = [
  { code: 'YANGI2026',     discountPct: 20, usageLimit: 500,  usedCount: 0,    status: 'active',  expiresInDays: 365, planSlug: 'oylik' },
  { code: 'CHEGIRMA50',    discountPct: 44, usageLimit: 1000, usedCount: 800,  status: 'archived', expiresInDays: 365, planSlug: null },
  { code: 'YOSHLAR123',    discountPct: 35, usageLimit: 600,  usedCount: 540,  status: 'archived', expiresInDays: 365, planSlug: 'yillik' },
  { code: 'FARZANDIMNEW',  discountPct: 60, usageLimit: 1000, usedCount: 1000, status: 'inactive', expiresInDays: 365, planSlug: 'oylik' },
];

interface PaymentSeed {
  userName: string;
  planSlug: string;
  amount: number;
  method: 'click' | 'payme' | 'uzum_bank' | 'visa' | 'mastercard';
  status: 'success' | 'pending' | 'failed' | 'refunded';
  minutesAgo: number;
}

const PAYMENTS: PaymentSeed[] = [
  { userName: 'Ahmad', planSlug: 'oylik',  amount: 29_000,  method: 'click',     status: 'success', minutesAgo: 60 * 2 },
  { userName: 'Ahmad', planSlug: 'yillik', amount: 290_000, method: 'payme',     status: 'success', minutesAgo: 60 * 24 * 30 * 3 },
  { userName: 'Р',     planSlug: 'oylik',  amount: 29_000,  method: 'uzum_bank', status: 'pending', minutesAgo: 60 * 6 },
  { userName: 'Ahmad', planSlug: 'oylik',  amount: 29_000,  method: 'click',     status: 'failed',  minutesAgo: 60 * 24 * 2 },
];

async function main(): Promise<void> {
  // PLANS — upsert by slug.
  for (const plan of PLANS) {
    await prisma.plan.upsert({
      where: { slug: plan.slug },
      update: {
        name: plan.name,
        description: plan.description,
        priceUzs: plan.priceUzs,
        period: plan.period,
        entitlementTier: plan.entitlementTier,
        badge: plan.badge,
        features: plan.features,
        sortOrder: plan.sortOrder,
        isActive: true,
      },
      create: {
        slug: plan.slug,
        name: plan.name,
        description: plan.description,
        priceUzs: plan.priceUzs,
        period: plan.period,
        entitlementTier: plan.entitlementTier,
        badge: plan.badge,
        features: plan.features,
        sortOrder: plan.sortOrder,
      },
    });
  }
  console.log(`Plans upserted: ${PLANS.length}`);

  // PROMOCODES — upsert by code, with optional plan binding.
  const planBySlug = new Map(
    (await prisma.plan.findMany({ select: { id: true, slug: true } })).map((p) => [p.slug, p.id]),
  );
  for (const p of PROMOS) {
    const planId = p.planSlug ? planBySlug.get(p.planSlug) ?? null : null;
    await prisma.promocode.upsert({
      where: { code: p.code },
      update: {
        discountPct: p.discountPct,
        usageLimit: p.usageLimit,
        usedCount: p.usedCount,
        expiresAt: new Date(Date.now() + p.expiresInDays * 86_400_000),
        status: p.status,
        planId,
      },
      create: {
        code: p.code,
        discountPct: p.discountPct,
        usageLimit: p.usageLimit,
        usedCount: p.usedCount,
        expiresAt: new Date(Date.now() + p.expiresInDays * 86_400_000),
        status: p.status,
        planId,
      },
    });
  }
  console.log(`Promocodes upserted: ${PROMOS.length}`);

  // PAYMENTS — reset and reseed (synthetic demo rows).
  await prisma.payment.deleteMany();
  for (const pay of PAYMENTS) {
    const user = await prisma.user.findFirst({ where: { name: pay.userName } });
    const plan = planBySlug.get(pay.planSlug);
    if (!user || !plan) continue;
    await prisma.payment.create({
      data: {
        userId: user.id,
        planId: plan,
        planName: PLANS.find((p) => p.slug === pay.planSlug)?.name ?? null,
        amount: pay.amount,
        method: pay.method,
        status: pay.status,
        createdAt: new Date(Date.now() - pay.minutesAgo * 60_000),
      },
    });
  }
  const paid = await prisma.payment.count();
  console.log(`Payments seeded: ${paid}`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
