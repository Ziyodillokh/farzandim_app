/**
 * Test parent + bola yaratish va JWT tokenlar generatsiyasi.
 *
 * Ishlatish: tsx scripts/seed-test-user.ts
 */
import { PrismaClient } from '@prisma/client';
import * as jwt from 'jsonwebtoken';
import * as dotenv from 'dotenv';

dotenv.config();

const prisma = new PrismaClient();

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET!;
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET!;
const TEST_TELEGRAM_ID = '999000001';

async function main() {
  // 1) Parent user — telegramId orqali upsert
  const parent = await prisma.user.upsert({
    where: { telegramId: TEST_TELEGRAM_ID },
    update: {},
    create: {
      telegramId: TEST_TELEGRAM_ID,
      role: 'PARENT',
      name: 'Aliyev Test',
      language: 'uz',
    },
  });
  console.log(`Parent: ${parent.id} (${parent.name})`);

  // 2) Test bola — agar yo'q bo'lsa yarat
  let child = await prisma.child.findFirst({
    where: { parentId: parent.id },
  });
  if (!child) {
    child = await prisma.child.create({
      data: {
        parentId: parent.id,
        name: 'Asilbek',
        age: 9,
        gender: 'male',
        region: 'Toshkent',
        familyCode: '482710',
        isConnected: true,
        batteryLevel: 67,
        isCharging: false,
        deviceModel: 'Redmi Note 12',
        androidVersion: '13',
        appVersion: '1.0.0',
        lastSeenAt: new Date(),
      },
    });
    console.log(`Child: ${child.id} (${child.name}, code: ${child.familyCode})`);
  } else {
    console.log(`Child mavjud: ${child.id}`);
  }

  // 3) Ikkinchi bola — carousel ko'rinishi uchun
  let child2 = await prisma.child.findFirst({
    where: { parentId: parent.id, name: 'Madina' },
  });
  if (!child2) {
    child2 = await prisma.child.create({
      data: {
        parentId: parent.id,
        name: 'Madina',
        age: 12,
        gender: 'female',
        region: 'Toshkent',
        familyCode: '731205',
        isConnected: false,
        batteryLevel: 23,
      },
    });
    console.log(`Child 2: ${child2.id} (${child2.name})`);
  }

  // 4) JWT tokens
  const payload = { userId: parent.id, role: parent.role, tokenVersion: parent.tokenVersion };
  const accessToken = jwt.sign(payload, ACCESS_SECRET, {
    expiresIn: '24h',
    audience: 'farzandim-consumer',
    issuer: 'farzandim-backend',
  });
  const refreshToken = jwt.sign(payload, REFRESH_SECRET, {
    expiresIn: '30d',
    audience: 'farzandim-consumer',
    issuer: 'farzandim-backend',
  });

  console.log('\n========== FRONTEND LOCALSTORAGE ==========');
  console.log(JSON.stringify({
    state: {
      user: {
        id: parent.id,
        name: parent.name,
        phone: parent.phone,
        role: parent.role,
        avatarUrl: parent.avatarUrl,
        telegramId: parent.telegramId,
        language: parent.language,
      },
      accessToken,
      refreshToken,
      isAuthenticated: true,
    },
    version: 0,
  }, null, 2));
  console.log('===========================================\n');

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
