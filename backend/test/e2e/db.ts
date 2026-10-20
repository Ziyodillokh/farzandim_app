// Test bazasini tozalash — har test faylidan oldin (migratsiyalar jadvali
// saqlanadi).

import type { PrismaClient } from '@prisma/client';

export async function resetDb(prisma: PrismaClient): Promise<void> {
  const rows = await prisma.$queryRaw<{ tablename: string }[]>`
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public' AND tablename <> '_prisma_migrations'`;
  if (rows.length === 0) return;
  const tables = rows.map((r) => `"public"."${r.tablename}"`).join(', ');
  await prisma.$executeRawUnsafe(`TRUNCATE TABLE ${tables} RESTART IDENTITY CASCADE`);
}
