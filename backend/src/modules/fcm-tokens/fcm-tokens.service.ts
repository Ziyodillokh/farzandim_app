import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { RegisterTokenDto } from './dto/register-token.dto';

@Injectable()
export class FcmTokensService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmService,
  ) {}

  /* ------------------------------------------------------------------ */
  /*  POST /fcm/test — o'ziga test push yuborish (diagnostika)           */
  /*  Natija: nechta token ro'yxatda + nechtasi yuborildi/yiqildi.       */
  /*  PII yo'q — faqat sonlar qaytadi.                                   */
  /* ------------------------------------------------------------------ */

  async sendTestPush(userId: string) {
    const tokens = await this.prisma.fcmToken.count({ where: { userId } });
    const result = await this.fcm.sendPushToUser(userId, {
      title: '✅ Test push',
      body: 'Bu test bildirishnomasi — push tizimi ishlayapti.',
      data: { type: 'test' },
    });
    return {
      tokens,
      sent: result.sent,
      failed: result.failed,
      invalid: result.invalidTokens.length,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /fcm/tokens — register (upsert)                              */
  /* ------------------------------------------------------------------ */

  async register(userId: string, dto: RegisterTokenDto) {
    const row = await this.prisma.fcmToken.upsert({
      where: { token: dto.token },
      update: {
        userId,
        deviceType: dto.deviceType ?? null,
        deviceId: dto.deviceId ?? null,
      },
      create: {
        userId,
        token: dto.token,
        deviceType: dto.deviceType ?? null,
        deviceId: dto.deviceId ?? null,
      },
    });

    return {
      id: row.id,
      deviceType: row.deviceType,
      deviceId: row.deviceId,
      createdAt: row.createdAt,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  GET /fcm/tokens — list user's tokens (without token value)         */
  /* ------------------------------------------------------------------ */

  async findAllByUser(userId: string) {
    const tokens = await this.prisma.fcmToken.findMany({
      where: { userId },
      select: {
        id: true,
        deviceType: true,
        deviceId: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    return { tokens, count: tokens.length };
  }

  /* ------------------------------------------------------------------ */
  /*  DELETE /fcm/tokens/:id — unregister single token                   */
  /* ------------------------------------------------------------------ */

  async remove(id: string, userId: string) {
    const row = await this.prisma.fcmToken.findUnique({ where: { id } });
    if (!row) {
      throw new NotFoundException('Token not found');
    }
    if (row.userId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    await this.prisma.fcmToken.delete({ where: { id } });
    return { ok: true };
  }

  /* ------------------------------------------------------------------ */
  /*  DELETE /fcm/tokens — unregister all tokens for user                */
  /* ------------------------------------------------------------------ */

  async removeAll(userId: string) {
    const result = await this.prisma.fcmToken.deleteMany({
      where: { userId },
    });
    return { ok: true, deleted: result.count };
  }
}
