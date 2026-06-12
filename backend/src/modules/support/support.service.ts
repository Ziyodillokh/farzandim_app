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
import { PrismaService } from '../../common/database/prisma.service';
import { TelegramSupportService } from './telegram-support.service';
import { CreateSupportMessageDto } from './dto/create-support-message.dto';

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

  constructor(
    private readonly storage: StorageService,
    private readonly prisma: PrismaService,
    private readonly telegram: TelegramSupportService,
  ) {}

  /* ─────────────────── Xabarlar (Telegram ko'prigi) ─────────────────── */

  /**
   * User xabarini saqlaydi, operatorlar guruhiga yuboradi va kerak bo'lsa
   * avto-javob ("tez orada javob beramiz") yaratadi.
   *
   * Avto-javob qoidasi: faqat suhbat "javoblangan" holatda bo'lsa (oxirgi
   * xabar operatorniki yoki umuman birinchi xabar) — user ketma-ket yozsa
   * har safar takrorlanmaydi.
   */
  async createMessage(userId: string, dto: CreateSupportMessageDto) {
    const text = dto.text?.trim();
    if (!text && !dto.attachmentKey) {
      throw new BadRequestException('Matn yoki biriktirma berilishi shart');
    }

    const previous = await this.prisma.supportMessage.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: { sender: true },
    });

    const message = await this.prisma.supportMessage.create({
      data: {
        userId,
        sender: 'user',
        text: text || null,
        attachmentKey: dto.attachmentKey ?? null,
        attachmentType: dto.attachmentType ?? null,
        fileName: dto.fileName ?? null,
        fileSize: dto.fileSize ?? null,
        mimeType: dto.mimeType ?? null,
      },
    });

    let ack: typeof message | null = null;
    if (!previous || previous.sender === 'operator') {
      ack = await this.prisma.supportMessage.create({
        data: { userId, sender: 'operator', isAutoAck: true },
      });
    }

    // Guruhga yuborish — fonda, xato chatni buzmaydi. message_id saqlanadi
    // (operator swipe-reply qilsa routing ishlashi uchun).
    void this.telegram
      .notifyNewUserMessage({
        userId,
        text: message.text,
        attachmentType: message.attachmentType,
        fileName: message.fileName,
        attachmentKey: message.attachmentKey,
      })
      .then(async (tgId) => {
        if (tgId != null) {
          await this.prisma.supportMessage.update({
            where: { id: message.id },
            data: { tgMessageId: tgId },
          });
        }
      })
      .catch((e: Error) =>
        this.logger.warn(`TG notify xato: ${e.message}`),
      );

    return { message, ack };
  }

  /** Suhbat tarixi (oxirgi 200 ta, eskidan yangiga). */
  async listMessages(userId: string) {
    const rows = await this.prisma.supportMessage.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    return { messages: rows.reverse() };
  }

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
