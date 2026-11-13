// Ota-onani o'quvchiga bog'lash. Telefon — odamning kaliti: shu maktabda shu raqamli ota-ona bo'lsa, yangi
// yozuv ochilmaydi, mavjudi bog'lanadi. Shunda aka-uka / opa-singil bitta ota-ona yozuvi va BITTA taklif kodi
// bilan ulanadi (ota-ona ilovada bir marta kod kiritadi — hamma farzandi ko'rinadi). Mavjud yozuvning ismi va
// kimligi o'zgartirilmaydi. Bir vaqtda kelgan ikki so'rov ikkita yozuv ochmasligi uchun (maktab, telefon) qulfi.

import { Prisma, SchoolGuardian } from '@prisma/client';
import type { GuardianData } from './students.schemas';

type Tx = Prisma.TransactionClient;

export interface AttachedGuardian {
  guardian: SchoolGuardian;
  /** `true` — shu telefonli mavjud ota-ona bog'landi (yangi yozuv ochilmadi). */
  reused: boolean;
  /** `true` — u allaqachon shu o'quvchiga bog'langan edi (hech narsa o'zgarmadi). */
  alreadyLinked: boolean;
}

export async function attachGuardian(tx: Tx, schoolId: string, studentId: string, input: GuardianData): Promise<AttachedGuardian> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`school-guardian-phone:${schoolId}:${input.phone}`}, 0))`;
  const existing = await tx.schoolGuardian.findFirst({
    where: { schoolId, phone: input.phone },
    orderBy: { createdAt: 'asc' },
    include: { students: { where: { studentId }, select: { studentId: true } } },
  });
  if (!existing) {
    const guardian = await tx.schoolGuardian.create({ data: { ...input, schoolId, students: { create: [{ studentId }] } } });
    return { guardian, reused: false, alreadyLinked: false };
  }
  const { students, ...guardian } = existing;
  if (students.length > 0) return { guardian, reused: true, alreadyLinked: true };
  await tx.schoolStudentGuardian.create({ data: { studentId, guardianId: guardian.id } });
  return { guardian, reused: true, alreadyLinked: false };
}
