// Bog'lanish amallarining tranzaksion (advisory) qulflari. Deadlock bo'lmasligi uchun qulf KALITLARI doim shu
// tartibda olinadi: kod maydoni (1) -> bola (2) -> o'quvchi (3). Kalitlar leksikografik saralanadi va raqam
// prefiksi tartibni kafolatlaydi, shuning uchun bir `acquireLinkLocks` chaqiruvi ichida ham, ketma-ket
// chaqiruvlarda ham (avval bola, keyin o'quvchi) tsikl yuzaga kelmaydi.

import { Prisma } from '@prisma/client';

type Tx = Prisma.TransactionClient;

/** Yangi kod berish: barcha generatsiyalar ketma-ket (faol kodlar orasida yagonalik). */
export const CODE_SPACE_LOCK = 'link:1:codes';
export const childLock = (childId: string) => `link:2:child:${childId}`;
export const studentLock = (studentId: string) => `link:3:student:${studentId}`;

/** Tranzaksiya tugaguncha ushlab turiladigan qulflar (takroriy kalitlar bir marta). */
export async function acquireLinkLocks(tx: Tx, keys: readonly string[]): Promise<void> {
  for (const key of [...new Set(keys)].sort()) {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${key}, 0))`;
  }
}
