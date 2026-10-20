// Yangi maktab va direktor hisobini yaratish (bir martalik, serverda):
//
//   npx tsx scripts/school/create-school.ts --code parvoz-14 \
//     --name "14-maktab" --city Toshkent --director "Karimov Akmal" --username direktor
//
// Parol avtomatik yaratiladi va BIR MARTA chiqariladi — birinchi kirishda
// direktor uni almashtiradi.

import { PrismaClient } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { createSchoolWithDirector } from '../../src/school/common/school-bootstrap';

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main(): Promise<void> {
  const code = arg('code');
  const name = arg('name');
  const director = arg('director');
  if (!code || !name || !director) {
    throw new Error('Kerak: --code --name --director [--username] [--city] [--short]');
  }
  const password = randomBytes(9).toString('base64url');
  const prisma = new PrismaClient();
  try {
    const { school, director: staff } = await createSchoolWithDirector(prisma, {
      code,
      name,
      shortName: arg('short'),
      city: arg('city'),
      director: { fullName: director, username: arg('username') ?? 'direktor', password },
    });
    process.stdout.write(
      [
        `Maktab yaratildi: ${school.name} (kod: ${school.code})`,
        `Direktor: ${staff.fullName}`,
        `Login: ${staff.username}`,
        `Vaqtinchalik parol: ${password}`,
        'Birinchi kirishda parolni almashtirish so\'raladi.',
        '',
      ].join('\n'),
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  process.stderr.write(`${(e as Error).message}\n`);
  process.exit(1);
});
