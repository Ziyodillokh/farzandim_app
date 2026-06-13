// ─────────────────────────────────────────────────────────────────────
// seed-admin.js — demo/super-admin moderator yaratish yoki parolini tiklash
// ─────────────────────────────────────────────────────────────────────
//
// Foydalanish (backend papkasidan):
//   node scripts/seed-admin.js
//   node scripts/seed-admin.js admin@farzandim.uz "Parol123!" "Super Admin"
//
// Argumentlar (ixtiyoriy): <email> <password> <name>
// Mavjud bo'lsa parol + rol + status yangilanadi (upsert), aks holda yaratiladi.
// Parol bcryptjs bilan hashlanadi (login bilan bir xil algoritm).

const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

const email = (process.argv[2] || 'admin@farzandim.uz').toLowerCase().trim();
const password = process.argv[3] || 'Admin12345';
const name = process.argv[4] || 'Demo Admin';

(async () => {
  try {
    const passwordHash = await bcrypt.hash(password, 10);

    const admin = await prisma.moderator.upsert({
      where: { email },
      update: {
        passwordHash,
        moderatorRoleKey: 'super_admin',
        status: 'active',
        // Eski tokenlarni bekor qilamiz (xavfsizlik) va 2FA'ni o'chiramiz —
        // demo login to'siqsiz kirsin.
        tokenVersion: { increment: 1 },
        twoFactorEnabled: false,
        twoFactorSecret: null,
        twoFactorBackupCodes: [],
      },
      create: {
        name,
        email,
        passwordHash,
        moderatorRoleKey: 'super_admin',
        permissions: [],
        status: 'active',
      },
      select: { id: true, email: true, name: true, moderatorRoleKey: true, status: true },
    });

    console.log('✅ Admin tayyor:');
    console.log('   email   :', admin.email);
    console.log('   password:', password);
    console.log('   role    :', admin.moderatorRoleKey);
    console.log('   status  :', admin.status);
    console.log('   id      :', admin.id);
  } catch (e) {
    console.error('❌ Xato:', e.message);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
})();
