/**
 * Quick admin seed for NestJS backend.
 *
 * Usage:
 *   ADMIN_EMAIL=admin@farzandim.uz ADMIN_PASSWORD=Admin12345 npx tsx scripts/seed-admin-quick.ts
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const ALL_PERMISSIONS = [
  'view_users', 'manage_users', 'block_users', 'warn_users', 'edit_user_data',
  'view_content', 'approve_content', 'reject_content', 'edit_content', 'delete_content',
  'upload_audiobooks', 'edit_audiobooks', 'delete_audiobooks', 'approve_audiobooks',
  'create_contest', 'edit_contest', 'delete_contest', 'select_winner',
  'send_notifications', 'manage_notifications',
  'view_analytics', 'view_audit_log',
  'manage_monetization', 'view_payments',
  'manage_moderators',
  'manage_olympiads', 'manage_content',
];

async function main() {
  const email = process.env.ADMIN_EMAIL ?? 'admin@farzandim.uz';
  const password = process.env.ADMIN_PASSWORD ?? 'Admin12345';
  const name = process.env.ADMIN_NAME ?? 'Bosh administrator';

  const passwordHash = await bcrypt.hash(password, 10);

  const admin = await prisma.moderator.upsert({
    where: { email },
    update: { passwordHash, status: 'active' },
    create: {
      email,
      name,
      passwordHash,
      moderatorRoleKey: 'super_admin',
      permissions: ALL_PERMISSIONS,
      status: 'active',
    },
  });

  console.log('\n✅ Admin moderator yaratildi/yangilandi:');
  console.log(`   Email:    ${admin.email}`);
  console.log(`   Password: ${password}`);
  console.log(`   Role:     ${admin.moderatorRoleKey}`);
  console.log(`   ID:       ${admin.id}`);
  console.log(`   Status:   ${admin.status}\n`);

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error('Seed xato:', err);
  process.exit(1);
});
