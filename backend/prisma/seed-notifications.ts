/**
 * Sprint 5.3: seed demo admin notification broadcasts so the Bildirishnoma
 * page renders meaningful history + stats out of the box.
 *
 * Usage on server:
 *   tsx prisma/seed-notifications.ts
 */
import 'dotenv/config';
import { prisma } from '../src/lib/prisma';

interface NotificationSeed {
  title: string;
  message: string;
  targetType: 'all' | 'parents' | 'children' | 'premium' | 'age_group';
  status: 'sent' | 'scheduled' | 'failed';
  delivered: number;
  opened: number;
  clicked: number;
  minutesAgo: number;
}

const SEED: NotificationSeed[] = [
  {
    title: 'Yangi audiokitob: Sarguzashtlar kutmoqda',
    message: "Yangi audiokitob qo'shildi — bolangiz albatta yoqtiradi.",
    targetType: 'all',
    status: 'scheduled',
    delivered: 0,
    opened: 0,
    clicked: 0,
    minutesAgo: -120, // future
  },
  {
    title: "Tanlov haqida ogohlantirish: Ajoyib sovg'alarni yutib oling",
    message: "Yangi konkurs ochildi — eng ko'p ball to'plagan farzandlar sovg'a oladi.",
    targetType: 'premium',
    status: 'sent',
    delivered: 12450,
    opened: 9030,
    clicked: 5418,
    minutesAgo: 60 * 24 * 4,
  },
  {
    title: 'Yangilangan dastur: Harakatlanuvchi interfeys bilan',
    message: 'Yangi versiya 2.0 tayyor — yangi dizayn va tezroq tezlik.',
    targetType: 'parents',
    status: 'sent',
    delivered: 8200,
    opened: 7010,
    clicked: 3450,
    minutesAgo: 60 * 24 * 3,
  },
  {
    title: "Maxsus taklif: Xarid qiling va bonuslar oling",
    message: "Bir oylik tarif sotib oling — 1 oylik bepul kuni qo'shamiz.",
    targetType: 'parents',
    status: 'sent',
    delivered: 8120,
    opened: 5270,
    clicked: 1980,
    minutesAgo: 60 * 24 * 2,
  },
  {
    title: 'Ommaviy aksiyalar: Yangi mahsulotlarga chegirmalar',
    message: 'Premium tarifda 30% chegirma — faqat shu hafta.',
    targetType: 'all',
    status: 'sent',
    delivered: 20450,
    opened: 16070,
    clicked: 7820,
    minutesAgo: 60 * 24,
  },
  {
    title: "Foydalanuvchilarni rag'batlantirish: Mukofotlar dasturi",
    message: 'Yangi referral dasturi — har bir do\'st 5,000 so\'m bonus.',
    targetType: 'premium',
    status: 'failed',
    delivered: 0,
    opened: 0,
    clicked: 0,
    minutesAgo: 60 * 12,
  },
];

async function main(): Promise<void> {
  await prisma.adminNotification.deleteMany();
  for (const n of SEED) {
    const ts = new Date(Date.now() - n.minutesAgo * 60_000);
    const isScheduled = n.status === 'scheduled';
    await prisma.adminNotification.create({
      data: {
        title: n.title,
        message: n.message,
        targetType: n.targetType,
        status: n.status,
        scheduledAt: isScheduled ? ts : null,
        sentAt: n.status === 'sent' ? ts : null,
        deliveredCount: n.delivered,
        openedCount: n.opened,
        clickedCount: n.clicked,
        createdAt: n.status === 'sent' ? ts : new Date(),
      },
    });
  }
  const total = await prisma.adminNotification.count();
  console.log(`Admin notifications seeded: ${total}`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
