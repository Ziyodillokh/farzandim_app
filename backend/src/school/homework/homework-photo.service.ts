// Rasm proksisi: imzolangan havola -> MinIO baytlari. Imzo noto'g'ri / muddati o'tgan -> 403;
// rasm yoki obyekt yo'q -> 404 (500 emas).

import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { HomeworkPhotoUrlService } from './homework-photo-url.service';
import { HomeworkStorageService } from './homework-storage.service';

@Injectable()
export class HomeworkPhotoService {
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
    } catch {
      throw new NotFoundException('Photo object not found');
    }
  }
}
