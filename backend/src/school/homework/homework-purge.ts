// Yozma vazifa rasmlarini o'chirish yordamchilari: bola ma'lumotlari o'chirilganda
// (`ChildDataPurgeService`) va topshiriq o'chirilganda MinIO kalitlari DB qatorlaridan
// OLDIN yig'iladi (qatorlar cascade o'chadi), obyektlar keyin best-effort o'chiriladi.

import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { BUCKETS } from '../../common/storage/storage.constants';

type Db = Prisma.TransactionClient | PrismaService;

/** Shart bo'yicha topshiriqlarning barcha rasm kalitlari. */
export async function homeworkKeysOf(db: Db, where: Prisma.SchoolHomeworkSubmissionWhereInput): Promise<string[]> {
  const photos = await db.schoolHomeworkPhoto.findMany({ where: { submission: where }, select: { key: true } });
  return photos.map((p) => p.key);
}

/** Bolaga (Child) bog'langan o'quvchi topshiriqlari rasmlari — bola ma'lumotlarini o'chirish uchun. */
export async function homeworkMediaOfChild(db: Db, childId: string): Promise<{ bucket: typeof BUCKETS.schoolHomework; key: string }[]> {
  const keys = await homeworkKeysOf(db, { student: { childId } });
  return keys.map((key) => ({ bucket: BUCKETS.schoolHomework, key }));
}

/** Bolaga bog'langan o'quvchining barcha topshiriqlari (rasm qatorlari cascade). */
export function deleteHomeworkOfChild(tx: Prisma.TransactionClient, childId: string) {
  return tx.schoolHomeworkSubmission.deleteMany({ where: { student: { childId } } });
}
