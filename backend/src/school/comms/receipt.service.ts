// To'lov cheki rasmi: yuklash (ota-ona), imzolangan havola (xodim paneli) va proksi orqali o'qish.
// Imzo noto'g'ri / muddati o'tgan -> 403; rasm yoki obyekt yo'q -> 404; MinIO ishlamasa -> 503.

import { ForbiddenException, Injectable, Logger, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EnvConfig } from '../../common/config/env.schema';
import { PrismaService } from '../../common/database/prisma.service';
import { isMissingObject } from '../homework/homework-photo.service';
import { HomeworkStorageService } from '../homework/homework-storage.service';
import type { UploadedPhoto } from '../homework/homework-upload';
import { buildReceiptUrl, receiptKey, verifyReceiptSignature } from './receipt-photo';

@Injectable()
export class ReceiptService {
  private readonly logger = new Logger(ReceiptService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: HomeworkStorageService,
    private readonly config: ConfigService<EnvConfig, true>,
  ) {}

  /** MinIO'ga yuklaydi; saqlash ma'lumoti (`receipt*` ustunlari uchun). */
  async upload(schoolId: string, verificationId: string, photo: UploadedPhoto) {
    const key = receiptKey({ schoolId, verificationId, ext: photo.ext });
    await this.storage.upload(key, photo.buffer, photo.contentType);
    return { receiptKey: key, receiptType: photo.contentType, receiptSize: photo.buffer.length };
  }

  /** Yuklangan, lekin so'rov saqlanmagan rasm (409 va h.k.) — best-effort o'chirish. */
  async discard(key: string): Promise<void> {
    await this.storage.deleteKeys([key]);
  }

  url(verificationId: string): string {
    return buildReceiptUrl(
      this.config.get('PUBLIC_BASE_URL', { infer: true }),
      verificationId,
      this.config.get('JWT_ACCESS_SECRET', { infer: true }),
    );
  }

  async read(verificationId: string, exp: string | undefined, sig: string | undefined) {
    const secret = this.config.get('JWT_ACCESS_SECRET', { infer: true });
    if (!verifyReceiptSignature(verificationId, exp, sig, secret)) throw new ForbiddenException('Invalid or expired link');
    const row = await this.prisma.schoolVerificationRequest.findUnique({
      where: { id: verificationId },
      select: { receiptKey: true, receiptType: true },
    });
    if (!row?.receiptKey || !row.receiptType) throw new NotFoundException('Receipt not found');
    try {
      const object = await this.storage.read(row.receiptKey);
      return { body: object.body, contentType: row.receiptType };
    } catch (err) {
      if (isMissingObject(err)) throw new NotFoundException('Receipt object not found');
      this.logger.error(`to'lov cheki o'qilmadi (${verificationId}): ${String(err)}`);
      throw new ServiceUnavailableException('Storage unavailable');
    }
  }
}
