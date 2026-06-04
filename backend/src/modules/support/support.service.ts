import {
  Injectable,
  Logger,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { extname } from 'path';
import { StorageService } from '../../common/storage/storage.service';
import { BUCKETS } from '../../common/storage/storage.constants';

// Multipart bodyLimit (main.ts) bilan bir xil — 100 MB.
const MAX_SIZE = 100 * 1024 * 1024;

/**
 * Qo'llab-quvvatlash chati biriktirmalari (rasm / video / hujjat).
 *
 * Faqat FAYL MinIO'da saqlanadi — chat xabarlari klientda (lokal) turadi,
 * shu sababli alohida DB modeli kerak emas. Yuborilgan `key` klientda
 * saqlanadi va keyin proxy orqali ko'rsatiladi/yuklab olinadi (signed URL
 * telefondan yetib bo'lmaydigan ichki MinIO manzilini chetlaydi — app-icon
 * proxy bilan bir xil yondashuv).
 */
@Injectable()
export class SupportService {
  private readonly logger = new Logger(SupportService.name);

  constructor(private readonly storage: StorageService) {}

  /** Biriktirmani MinIO'ga yuklaydi va klient saqlaydigan `key` qaytaradi. */
  async uploadAttachment(
    userId: string,
    file: { buffer: Buffer; mimetype?: string; filename?: string },
  ) {
    if (!file.buffer || file.buffer.length === 0) {
      throw new BadRequestException("Bo'sh fayl");
    }
    if (file.buffer.length > MAX_SIZE) {
      throw new BadRequestException('Fayl juda katta (maks 100 MB)');
    }

    // Key: `{userId}_{uuid}{ext}` — bitta segment (slash yo'q → oddiy
    // path param), userId egasini bildiradi, uuid taxmin qilib bo'lmaydi.
    const ext = extname(file.filename ?? '') || '';
    const key = `${userId}_${randomUUID()}${ext}`;
    const contentType = file.mimetype || 'application/octet-stream';

    try {
      await this.storage.upload(BUCKETS.support, key, file.buffer, contentType);
    } catch (err) {
      this.logger.error('Support attachment upload failed', err as Error);
      throw new InternalServerErrorException('Fayl yuklashda xatolik');
    }

    return {
      key,
      fileName: file.filename ?? key,
      mimeType: contentType,
      size: file.buffer.length,
    };
  }

  /** Biriktirmani MinIO'dan o'qiydi (proxy stream uchun). */
  async getAttachment(key: string): Promise<{ body: Buffer; contentType: string }> {
    return this.storage.getObject(BUCKETS.support, key);
  }
}
