// Himoyalangan rol (psixolog) hisobini yaratish yoki parolini tiklash —
// faqat operator, serverda. Direktor panel orqali bu rolni bera olmaydi:
// psixolog bolaning murojaatlari va test javoblarini ko'radi.
//
//   npx tsx scripts/school/create-staff.ts --school parvoz-14 --role PSYCHOLOGIST \
//     --name "Yusupova Malika" --username psixolog [--position "Psixolog"] [--phone "+998 90 123 45 67"]
//   npx tsx scripts/school/create-staff.ts --school parvoz-14 --username psixolog --reset [--reset-2fa]
//   # direktor hisobni o'chirgan bo'lsa (login yo'q) — o'sha xodimga qayta login:
//   npx tsx scripts/school/create-staff.ts --school parvoz-14 --id <xodim-id> --username psixolog --reset
//
// Vaqtinchalik parol BIR MARTA chiqariladi; birinchi kirishda almashtiriladi.

import { PrismaClient, SchoolStaffRole } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { isProtectedRole } from '../../src/school/auth/permissions';
import { hashStaffPassword } from '../../src/school/auth/school-auth.service';

const OPERATOR = 'Parvoz operatori';

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main(): Promise<void> {
  const code = arg('school')?.trim().toLowerCase();
  const username = arg('username')?.trim().toLowerCase();
  const staffId = arg('id')?.trim();
  const reset = process.argv.includes('--reset');
  const resetTotp = process.argv.includes('--reset-2fa');
  if (!code || !username || !/^[a-z0-9._-]{3,32}$/.test(username)) {
    throw new Error('Kerak: --school <kod> --username <login> [--role PSYCHOLOGIST --name "F.I.Sh."] [--reset [--id <xodim-id>] [--reset-2fa]]');
  }
  if ((staffId || resetTotp) && !reset) throw new Error('--id va --reset-2fa faqat --reset bilan');
  const password = randomBytes(9).toString('base64url');
  const prisma = new PrismaClient();
  try {
    const school = await prisma.school.findUnique({ where: { code } });
    if (!school) throw new Error(`Maktab topilmadi: ${code}`);
    const passwordHash = await hashStaffPassword(password);
    const byLogin = await prisma.schoolStaff.findUnique({ where: { schoolId_username: { schoolId: school.id, username } } });

    const staff = await prisma.$transaction(async (tx) => {
      const save = async () => {
        if (reset) {
          const target = staffId ? await tx.schoolStaff.findFirst({ where: { id: staffId, schoolId: school.id } }) : byLogin;
          if (!target) throw new Error(`Xodim topilmadi: ${staffId ?? username}`);
          if (byLogin && byLogin.id !== target.id) throw new Error(`Login band: ${username}`);
          const updated = await tx.schoolStaff.update({
            where: { id: target.id },
            data: {
              username,
              passwordHash,
              mustChangePassword: true,
              failedLogins: 0,
              lockedUntil: null,
              tokenVersion: { increment: 1 },
              ...(resetTotp && { totpEnabled: false, totpSecret: null }),
            },
          });
          await tx.schoolStaffSession.updateMany({ where: { staffId: target.id, revokedAt: null }, data: { revokedAt: new Date() } });
          return updated;
        }
        const role = arg('role') as SchoolStaffRole | undefined;
        const fullName = arg('name')?.trim();
        if (!role || !isProtectedRole(role)) throw new Error('--role himoyalangan rol bo\'lishi kerak (masalan, PSYCHOLOGIST)');
        if (!fullName) throw new Error('--name kerak');
        if (byLogin) throw new Error(`Login band: ${username} (parolni tiklash uchun --reset)`);
        return tx.schoolStaff.create({
          data: {
            schoolId: school.id,
            fullName,
            position: arg('position') ?? 'Psixolog',
            phone: arg('phone') ?? '',
            role,
            username,
            passwordHash,
            mustChangePassword: true,
          },
        });
      };
      const saved = await save();
      await tx.schoolAuditLog.create({
        data: {
          schoolId: school.id,
          actorName: OPERATOR,
          module: 'STAFF',
          action: reset ? 'staff.accountReset' : 'staff.accountCreate',
          entityId: saved.id,
          summary: `Panel hisobi: ${saved.fullName} (${username}) — operator${resetTotp ? ', 2FA o\'chirildi' : ''}`,
          params: { name: saved.fullName, username },
        },
      });
      return saved;
    });
    process.stdout.write(
      [
        `${reset ? 'Parol tiklandi' : 'Xodim yaratildi'}: ${staff.fullName} (${staff.role})`,
        `Maktab: ${school.name} (kod: ${school.code})`,
        `Login: ${username}`,
        `Vaqtinchalik parol: ${password}`,
        ...(resetTotp ? ['2FA o\'chirildi — kirgach qayta yoqish mumkin.'] : []),
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
