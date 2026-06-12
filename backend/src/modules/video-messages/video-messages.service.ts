import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  UnsupportedMediaTypeException,
  PayloadTooLargeException,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../common/database/prisma.service';
import { StorageService } from '../../common/storage/storage.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { BUCKETS } from '../../common/storage/storage.constants';
import { findFamilyLink } from '../../common/helpers/family-link';

const USER_SELECT = { id: true, name: true, role: true, avatarUrl: true } as const;

// Browser MediaRecorder formatlari ham qabul qilinishi uchun prefix bo'yicha
// tekshiramiz (masalan, "video/webm;codecs=vp8,opus" yoki "video/mp4;codec=h264").
const ALLOWED_VIDEO_MIME_PREFIXES = [
  'video/mp4',
  'video/quicktime',
  'video/webm',
  'video/3gpp',
  'video/x-matroska',
  'video/mpeg',
  'video/ogg',
];
const MAX_VIDEO_SIZE_BYTES = 100 * 1024 * 1024; // 100 MB

function isVideoMimeAllowed(mime: string): boolean {
  if (!mime) return false;
  const lower = mime.toLowerCase();
  return ALLOWED_VIDEO_MIME_PREFIXES.some((prefix) => lower.startsWith(prefix));
}

@Injectable()
export class VideoMessagesService {
  private readonly logger = new Logger(VideoMessagesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly fcm: FcmService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async send(
    senderId: string,
    receiverId: string,
    durationSeconds: number | undefined,
    file: { buffer: Buffer; mimetype: string; filename: string },
  ) {
    if (!isVideoMimeAllowed(file.mimetype)) {
      throw new UnsupportedMediaTypeException(
        `Unsupported video format: ${file.mimetype}`,
      );
    }

    if (!receiverId) {
      throw new BadRequestException('receiverId required');
    }

    if (receiverId === senderId) {
      throw new BadRequestException('Cannot send to yourself');
    }

    if (file.buffer.length > MAX_VIDEO_SIZE_BYTES) {
      throw new PayloadTooLargeException(`File too large, max ${MAX_VIDEO_SIZE_BYTES} bytes`);
    }

    const receiver = await this.prisma.user.findUnique({ where: { id: receiverId } });
    if (!receiver) {
      throw new NotFoundException('Receiver not found');
    }

    const link = await findFamilyLink(this.prisma, senderId, receiverId);
    if (!link) {
      throw new ForbiddenException('Sender and receiver are not in the same family');
    }

    const ext = file.filename?.split('.').pop() || 'mp4';
    const messageId = randomUUID();
    const storagePath = `${senderId}/${messageId}.${ext}`;

    try {
      await this.storage.upload(BUCKETS.video, storagePath, file.buffer, file.mimetype);
    } catch (err) {
      this.logger.error('Storage upload failed', err);
      throw new InternalServerErrorException('Storage upload failed');
    }

    const videoMessage = await this.prisma.videoMessage.create({
      data: {
        id: messageId,
        senderId,
        receiverId,
        storagePath,
        durationSeconds:
          durationSeconds !== undefined && !Number.isNaN(durationSeconds)
            ? Math.round(durationSeconds)
            : null,
      },
      include: {
        sender: { select: USER_SELECT },
        receiver: { select: USER_SELECT },
      },
    });

    this.realtime.emitToUser(receiverId, 'video:received', videoMessage);

    try {
      await this.fcm.sendPushToUser(receiverId, {
        title: videoMessage.sender.name ?? 'Yangi xabar',
        body: 'Video xabar yubordi',
        data: {
          type: 'video',
          messageId: videoMessage.id,
          senderId,
        },
      });
    } catch (err) {
      this.logger.warn(`Video push failed for message ${videoMessage.id}`, err);
    }

    return videoMessage;
  }

  async list(
    userId: string,
    opts: {
      role?: 'sent' | 'received';
      peerId?: string;
      before?: string;
      limit?: number;
    } = {},
  ) {
    const { role, peerId, before, limit } = opts;
    let where: any;
    if (peerId) {
      // Chat ekrani: faqat shu ikki user orasidagi yozishmalar.
      where = {
        OR: [
          { senderId: userId, receiverId: peerId },
          { senderId: peerId, receiverId: userId },
        ],
      };
    } else if (role === 'received') {
      where = { receiverId: userId };
    } else if (role === 'sent') {
      where = { senderId: userId };
    } else {
      where = { OR: [{ senderId: userId }, { receiverId: userId }] };
    }
    if (before) {
      // Cursor: eski sahifa so'ralganda shu vaqtdan oldingilar.
      where = { AND: [where, { createdAt: { lt: new Date(before) } }] };
    }

    const take = limit ?? 100;
    const messages = await this.prisma.videoMessage.findMany({
      where,
      include: {
        sender: { select: USER_SELECT },
        receiver: { select: USER_SELECT },
      },
      orderBy: { createdAt: 'desc' },
      take,
    });

    // hasMore: to'liq sahifa qaytdi = ehtimol yana bor (klient keyingi
    // before bilan tekshiradi). Eski klientlar bu maydonni o'qimaydi.
    return { messages, count: messages.length, hasMore: messages.length === take };
  }

  async getFileUrl(userId: string, messageId: string) {
    const message = await this.prisma.videoMessage.findUnique({
      where: { id: messageId },
    });
    if (!message) {
      throw new NotFoundException('Video message not found');
    }
    if (message.senderId !== userId && message.receiverId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    try {
      const url = await this.storage.getSignedUrl(BUCKETS.video, message.storagePath, 3600);
      return { url, expiresIn: 3600 };
    } catch (err) {
      this.logger.error('Could not generate URL', err);
      throw new InternalServerErrorException('Could not generate URL');
    }
  }

  /**
   * Video faylni MinIO'dan o'qiydi (proxy stream uchun).
   *
   * Signed URL telefondan yetib bo'lmaydigan ichki MinIO manzilini
   * qaytaradi — shu sabab proxy. `:id` UUID = capability URL, shuning
   * uchun `@Public` xavfsiz (avatar/support/chat-media bilan bir xil).
   * video_player shu URL'dan to'g'ridan o'ynaydi va birinchi kadrni
   * thumbnail sifatida ko'rsatadi.
   */
  async getVideoStream(
    id: string,
  ): Promise<{ body: Buffer; contentType: string }> {
    const message = await this.prisma.videoMessage.findUnique({
      where: { id },
    });
    if (!message || !message.storagePath) {
      throw new NotFoundException('Video topilmadi');
    }
    return this.storage.getObject(BUCKETS.video, message.storagePath);
  }

  async remove(userId: string, messageId: string) {
    const message = await this.prisma.videoMessage.findUnique({
      where: { id: messageId },
    });
    if (!message) {
      throw new NotFoundException('Video message not found');
    }
    if (message.senderId !== userId && message.receiverId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    try {
      await this.storage.delete(BUCKETS.video, message.storagePath);
    } catch (err) {
      this.logger.warn('MinIO delete failed, removing DB row anyway', err);
    }

    await this.prisma.videoMessage.delete({ where: { id: messageId } });

    return { ok: true };
  }
}
