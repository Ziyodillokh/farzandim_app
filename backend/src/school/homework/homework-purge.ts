// Yozma vazifa rasmlarini o'chirish yordamchilari: bola ma'lumotlari o'chirilganda
// (`ChildDataPurgeService`) va topshiriq o'chirilganda MinIO kalitlari DB qatorlaridan
// OLDIN yig'iladi (qatorlar cascade o'chadi), obyektlar keyin best-effort o'chiriladi.

import { Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { BUCKETS } from '../../common/storage/storage.constants';
import type { StorageService } from '../../common/storage/storage.service';

type Db = Prisma.TransactionClient | PrismaService;

/** Shart bo'yicha topshiriqlarning barcha rasm kalitlari. */
export async function homeworkKeysOf(db: Db, where: Prisma.SchoolHomeworkSubmissionWhereInput): Promise<string[]> {
  const photos = await db.schoolHomeworkPhoto.findMany({ where: { submission: where }, select: { key: true } });
  return photos.map((p) => p.key);
}

/** Bolalarga (Child) bog'langan o'quvchilar topshiriqlari rasmlari — bola ma'lumotlarini o'chirish uchun. */
export async function homeworkMediaOfChildren(
  db: Db,
  childIds: readonly string[],
): Promise<{ bucket: typeof BUCKETS.schoolHomework; key: string }[]> {
  if (childIds.length === 0) return [];
  const keys = await homeworkKeysOf(db, { student: { childId: { in: [...childIds] } } });
  return keys.map((key) => ({ bucket: BUCKETS.schoolHomework, key }));
}

/** Bolalarga bog'langan o'quvchilarning barcha topshiriqlari (rasm qatorlari cascade). */
export function deleteHomeworkOfChildren(tx: Prisma.TransactionClient, childIds: readonly string[]) {
  return tx.schoolHomeworkSubmission.deleteMany({ where: { student: { childId: { in: [...childIds] } } } });
}

/** MinIO obyektlarini BEST-EFFORT o'chirish (bittasi yiqilsa qolganlari davom etadi, faqat log). */
export async function deleteHomeworkObjects(storage: Pick<StorageService, 'delete'>, keys: readonly string[], logger: Logger): Promise<void> {
  if (keys.length === 0) return;
  const results = await Promise.allSettled(keys.map((key) => storage.delete(BUCKETS.schoolHomework, key)));
  const failed = results.filter((r) => r.status === 'rejected').length;
  if (failed > 0) logger.warn(`vazifa rasmlari: ${failed}/${keys.length} obyekt o'chirilmadi`);
}
