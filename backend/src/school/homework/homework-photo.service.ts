// Rasm proksisi: imzolangan havola -> MinIO baytlari. Imzo noto'g'ri / muddati o'tgan -> 403;
// rasm yoki obyekt yo'q -> 404; MinIO ishlamasa -> 503 (log bilan, 404 emas).

import { ForbiddenException, Injectable, Logger, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { HomeworkPhotoUrlService } from './homework-photo-url.service';
import { HomeworkStorageService } from './homework-storage.service';

/** MinIO "obyekt yo'q" (S3 `NoSuchKey` / 404) — boshqa xatolar (uzilish, timeout) bundan farq qiladi. */
export function isMissingObject(err: unknown): boolean {
  const e = err as { name?: string; message?: string; $metadata?: { httpStatusCode?: number } } | null;
  return e?.name === 'NoSuchKey' || e?.name === 'NotFound' || e?.$metadata?.httpStatusCode === 404 || Boolean(e?.message?.includes('NoSuchKey'));
}

@Injectable()
export class HomeworkPhotoService {
  private readonly logger = new Logger(HomeworkPhotoService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: HomeworkStorageService,
    private readonly urls: HomeworkPhotoUrlService,
  ) {}

  async read(photoId: string, exp: string | undefined, sig: string | undefined) {
    if (!this.urls.isValid(photoId, exp, sig)) throw new ForbiddenException('Invalid or expired link');
    const photo = await this.prisma.schoolHomeworkPhoto.findUnique({ where: { id: photoId }, select: { key: true, contentType: true } });
    if (!photo) throw new NotFoundException('Photo not found');
    try {
      const object = await this.storage.read(photo.key);
      return { body: object.body, contentType: photo.contentType };
    } catch (err) {
      if (isMissingObject(err)) throw new NotFoundException('Photo object not found');
      this.logger.error(`vazifa rasmi o'qilmadi (${photoId}): ${String(err)}`);
      throw new ServiceUnavailableException('Storage unavailable');
    }
  }
}
