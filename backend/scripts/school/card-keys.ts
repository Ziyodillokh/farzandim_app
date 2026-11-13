// NTAG 424 DNA kartani sozlash uchun kalitlar — faqat operator, serverda
// (`SCHOOL_DATA_KEY` sozlangan muhitda). Maktab bosh kaliti bo'lmasa yaratiladi.
//
//   npx tsx scripts/school/card-keys.ts --school parvoz-14 --uid 04A1B2C3D4E5F6
//
// Kartaning UID'ini avval NFC telefon bilan o'qing (masalan NXP TagInfo). Chiqqan
// kalitlar bilan kartada (NXP TagXplorer yoki TagWriter):
//   - K0 — ilova bosh kaliti, K1 — SDMMetaRead (PICCData shifri), K2 — SDMFileRead (CMAC),
//     K3 va K4 — ishlatilmaydi, lekin zavod (nol) kalitida qoldirilmaydi;
//   - NDEF faylida SDM: UID va o'qish hisoblagichi aks ettiriladi, PICCData shifrlangan (K1),
//     SDMMAC (K2), SDMMACInputOffset = SDMMACOffset;
//   - manzil: https://farzandimedu.uz/k/?p=<PICCData, 32 hex>&c=<SDMMAC, 16 hex>.
// Kalitlar ekranga BIR MARTA chiqadi — hech qayerga saqlamang va yubormang.
// Bosh kaliti yo'q maktab zavod kalitlari bilan sozlangan kartalarni qabul qiladi (faqat sinov).

import { ConfigService } from '@nestjs/config';
import { PrismaClient } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import type { EnvConfig } from '../../src/common/config/env.schema';
import { deriveMetaKey, deriveTagKey, normalizeUid } from '../../src/school/attendance/card-sun';
import { SchoolCryptoService } from '../../src/school/common/school-crypto.service';

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main(): Promise<void> {
  const code = arg('school')?.trim().toLowerCase();
  const uidHex = normalizeUid(arg('uid') ?? '');
  if (!code || !uidHex || uidHex.length !== 14) throw new Error('Kerak: --school <kod> --uid <7 baytli UID, 14 hex>');
  const config = { get: () => process.env.SCHOOL_DATA_KEY } as unknown as ConfigService<EnvConfig, true>;
  const crypto = new SchoolCryptoService(config);
  if (!crypto.isConfigured()) throw new Error('SCHOOL_DATA_KEY sozlanmagan');
  const prisma = new PrismaClient();
  try {
    const school = await prisma.school.findUnique({ where: { code }, select: { id: true, cardKey: true } });
    if (!school) throw new Error(`Maktab topilmadi: ${code}`);
    if (!school.cardKey) {
      const fresh = crypto.encrypt(randomBytes(16).toString('hex'));
      await prisma.school.updateMany({ where: { id: school.id, cardKey: null }, data: { cardKey: fresh } });
    }
    const stored = await prisma.school.findUniqueOrThrow({ where: { id: school.id }, select: { cardKey: true } });
    const master = Buffer.from(crypto.decrypt(stored.cardKey ?? ''), 'hex');
    const uid = Buffer.from(uidHex, 'hex');
    const keys = {
      K0: deriveTagKey(master, uid, 0),
      K1: deriveMetaKey(master),
      K2: deriveTagKey(master, uid, 2),
      K3: deriveTagKey(master, uid, 3),
      K4: deriveTagKey(master, uid, 4),
    };
    console.log(`Maktab: ${code}, karta UID: ${uidHex}`);
    for (const [name, key] of Object.entries(keys)) console.log(`${name}: ${key.toString('hex').toUpperCase()}`);
    console.log('Manzil: https://farzandimedu.uz/k/?p={PICCData}&c={SDMMAC}');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err: unknown) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
