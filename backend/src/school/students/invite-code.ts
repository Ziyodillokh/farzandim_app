// Ota-ona taklif kodi: 8 belgi (32^8 ≈ 10^12; chalkashadigan 0/O, 1/I yo'q),
// 7 kun amal qiladi. Kriptografik tasodif; yagonalik bazadagi unique indeks bilan.

import { Prisma } from '@prisma/client';
import { randomInt } from 'node:crypto';

export const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const INVITE_CODE_LENGTH = 8;
export const INVITE_TTL_MS = 7 * 86_400_000;
const MAX_ATTEMPTS = 20;

export function randomInviteCode(): string {
  return Array.from({ length: INVITE_CODE_LENGTH }, () => INVITE_ALPHABET[randomInt(INVITE_ALPHABET.length)]).join('');
}

/** Bazada band bo'lmagan kod (to'qnashuv ehtimoli juda kichik — bir necha urinish yetadi). */
export async function uniqueInviteCode(tx: Prisma.TransactionClient, reserved: Set<string> = new Set()): Promise<string> {
  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const code = randomInviteCode();
    if (reserved.has(code)) continue;
    const taken = await tx.schoolGuardian.findUnique({ where: { inviteCode: code }, select: { id: true } });
    if (!taken) {
      reserved.add(code);
      return code;
    }
  }
  throw new Error('invite code space exhausted');
}
