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
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { BUCKETS } from '../../common/storage/storage.constants';
import { findFamilyLink } from '../../common/helpers/family-link';

const USER_SELECT = { id: true, name: true, role: true, avatarUrl: true } as const;

const ALLOWED_MIMES = [
  'audio/mp4',
  'audio/m4a',
  'audio/aac',
  'audio/mpeg',
  'audio/ogg',
  'audio/webm',
  'audio/wav',
];
const MAX_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB

@Injectable()
export class VoiceMessagesService {
  private readonly logger = new Logger(VoiceMessagesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly fcm: FcmService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async send(
    senderId: string,
    receiverId: string,
    durationSeconds: number | undefined,
    file: { buffer: Buffer; mimetype: string; filename: string },
  ) {
    if (!ALLOWED_MIMES.includes(file.mimetype)) {
      throw new UnsupportedMediaTypeException(
        `Unsupported audio format: ${file.mimetype}`,
      );
    }

    if (!receiverId) {
      throw new BadRequestException('receiverId required');
    }

    if (receiverId === senderId) {
      throw new BadRequestException('Cannot send to yourself');
    }

    if (file.buffer.length > MAX_SIZE_BYTES) {
      throw new PayloadTooLargeException(`File too large, max ${MAX_SIZE_BYTES} bytes`);
    }

    const receiver = await this.prisma.user.findUnique({ where: { id: receiverId } });
    if (!receiver) {
      throw new NotFoundException('Receiver not found');
    }

    const link = await findFamilyLink(this.prisma, senderId, receiverId);
    if (!link) {
      throw new ForbiddenException('Sender and receiver are not in the same family');
    }

    const ext = file.filename?.split('.').pop() || 'm4a';
    const messageId = randomUUID();
    const storagePath = `${senderId}/${messageId}.${ext}`;

    try {
      await this.storage.upload(BUCKETS.voice, storagePath, file.buffer, file.mimetype);
    } catch (err) {
      this.logger.error('Storage upload failed', err);
      throw new InternalServerErrorException('Storage upload failed');
    }

    const voiceMessage = await this.prisma.voiceMessage.create({
      data: {
        id: messageId,
        senderId,
        receiverId,
        storagePath,
        durationSeconds:
          durationSeconds !== undefined && !isNaN(durationSeconds)
            ? Math.round(durationSeconds)
            : null,
      },
      include: {
        sender: { select: USER_SELECT },
        receiver: { select: USER_SELECT },
      },
    });

    this.realtime.emitToUser(receiverId, 'voice:received', voiceMessage);

    try {
      await this.fcm.sendPushToUser(receiverId, {
        title: voiceMessage.sender.name ?? 'Yangi xabar',
        body: 'Ovozli xabar yubordi',
        data: {
          type: 'voice',
          messageId: voiceMessage.id,
          senderId,
        },
      });
    } catch (err) {
      this.logger.warn(`Voice push failed for message ${voiceMessage.id}`, err);
    }

    return voiceMessage;
  }

  async list(userId: string, role?: 'sent' | 'received') {
    let where: any;
    if (role === 'received') {
      where = { receiverId: userId };
    } else if (role === 'sent') {
      where = { senderId: userId };
    } else {
      where = { OR: [{ senderId: userId }, { receiverId: userId }] };
    }

    const messages = await this.prisma.voiceMessage.findMany({
      where,
      include: {
        sender: { select: USER_SELECT },
        receiver: { select: USER_SELECT },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    return { messages, count: messages.length };
  }

  async getFileUrl(userId: string, messageId: string) {
    const message = await this.prisma.voiceMessage.findUnique({
      where: { id: messageId },
    });
    if (!message) {
      throw new NotFoundException('Voice message not found');
    }
    if (message.senderId !== userId && message.receiverId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    try {
      const url = await this.storage.getSignedUrl(BUCKETS.voice, message.storagePath, 3600);
      return { url, expiresIn: 3600 };
    } catch (err) {
      this.logger.error('Could not generate URL', err);
      throw new InternalServerErrorException('Could not generate URL');
    }
  }

  async markAsRead(userId: string, messageId: string) {
    const message = await this.prisma.voiceMessage.findUnique({
      where: { id: messageId },
    });
    if (!message) {
      throw new NotFoundException('Voice message not found');
    }
    if (message.receiverId !== userId) {
      throw new ForbiddenException('Only receiver can mark as read');
    }

    return this.prisma.voiceMessage.update({
      where: { id: messageId },
      data: { isRead: true },
    });
  }

  async readAll(userId: string, fromUserId?: string) {
    const result = await this.prisma.voiceMessage.updateMany({
      where: {
        receiverId: userId,
        isRead: false,
        ...(fromUserId ? { senderId: fromUserId } : {}),
      },
      data: { isRead: true },
    });

    return { ok: true, updated: result.count };
  }

  async remove(userId: string, messageId: string) {
    const message = await this.prisma.voiceMessage.findUnique({
      where: { id: messageId },
    });
    if (!message) {
      throw new NotFoundException('Voice message not found');
    }
    if (message.senderId !== userId && message.receiverId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    try {
      await this.storage.delete(BUCKETS.voice, message.storagePath);
    } catch (err) {
      this.logger.warn('MinIO delete failed, removing DB row anyway', err);
    }

    await this.prisma.voiceMessage.delete({ where: { id: messageId } });

    return { ok: true };
  }
}
