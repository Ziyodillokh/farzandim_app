/**
 * Sprint 5.1: seed the first super_admin moderator + the 4 demo moderators
 * shown in the PDF mock.
 *
 * Run on the production server after `prisma migrate deploy` lands the
 * `add_moderator` migration:
 *
 *   ADMIN_SEED_PASSWORD="<strong-password>" tsx prisma/seed-admin.ts
 *
 * If ADMIN_SEED_PASSWORD is not provided the script generates a temporary
 * password and prints it (rotate on first login).
 */
import 'dotenv/config';
import { randomBytes } from 'node:crypto';
import { prisma } from '../src/lib/prisma';
import { hashPassword } from '../src/modules/admin-auth/password';
import { ADMIN_ROLE_PRESETS, sanitizePermissions } from '../src/lib/admin-permissions';

interface SeedRow {
  name: string;
  email: string;
  phone: string;
  moderatorRoleKey: keyof typeof ADMIN_ROLE_PRESETS;
  status: 'active' | 'blocked';
  lastActivityMinutesAgo: number;
}

const DEMO_ROWS: SeedRow[] = [
  {
    name: 'Bosh administrator',
    email: 'admin@farzandim.uz',
    phone: '+998 99 723 6562',
    moderatorRoleKey: 'super_admin',
    status: 'active',
    lastActivityMinutesAgo: 5,
  },
  {
    name: 'Karim Rasulov',
    email: 'finance@farzandim.uz',
    phone: '+998 99 723 4862',
    moderatorRoleKey: 'finance',
    status: 'blocked',
    lastActivityMinutesAgo: 60 * 24 * 30 * 5,
  },
  {
    name: 'Madina Karimova',
    email: 'content@farzandim.uz',
    phone: '+998 99 723 1234',
    moderatorRoleKey: 'content_maker',
    status: 'active',
    lastActivityMinutesAgo: 60 * 2,
  },
  {
    name: 'Sherzod Tashkentov',
    email: 'support@farzandim.uz',
    phone: '+998 99 723 5678',
    moderatorRoleKey: 'support',
    status: 'active',
    lastActivityMinutesAgo: 60 * 24 * 7,
  },
];

async function main(): Promise<void> {
  const seedPassword = process.env.ADMIN_SEED_PASSWORD ?? randomBytes(9).toString('base64url');
  const passwordHash = await hashPassword(seedPassword);

  for (const row of DEMO_ROWS) {
    const permissions = sanitizePermissions(ADMIN_ROLE_PRESETS[row.moderatorRoleKey] ?? []);
    await prisma.moderator.upsert({
      where: { email: row.email },
      update: {
        name: row.name,
        phone: row.phone,
        moderatorRoleKey: row.moderatorRoleKey,
        permissions,
        status: row.status,
      },
      create: {
        name: row.name,
        email: row.email,
        phone: row.phone,
        passwordHash,
        moderatorRoleKey: row.moderatorRoleKey,
        permissions,
        status: row.status,
        lastActivityAt: new Date(Date.now() - row.lastActivityMinutesAgo * 60_000),
      },
    });
  }

  const total = await prisma.moderator.count();
  console.log(`Seeded ${total} moderators.`);
  console.log(`Login: admin@farzandim.uz / ${seedPassword}`);
  if (!process.env.ADMIN_SEED_PASSWORD) {
    console.log('⚠️  Generated temporary password — change it immediately via the admin panel.');
  }
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
