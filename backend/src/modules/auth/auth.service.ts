import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { EnvConfig } from '../../common/config/env.schema';
import { TelegramService, TelegramAuthData } from './strategies/telegram.service';
import { TelegramAuthDto } from './dto/telegram-auth.dto';
import { ChildPairDto } from './dto/child-pair.dto';

const PAIR_REQUEST_TTL_MIN = 5;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly audit: AuditService,
    private readonly fcm: FcmService,
    private readonly realtime: RealtimeGateway,
    private readonly telegramService: TelegramService,
  ) {}

  /* ------------------------------------------------------------------ */
  /*  Token helpers                                                      */
  /* ------------------------------------------------------------------ */

  private signAccessToken(payload: JwtPayload): string {
    return this.jwtService.sign(
      { userId: payload.userId, role: payload.role, tokenVersion: payload.tokenVersion },
      {
        secret: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
        expiresIn: this.config.get('JWT_ACCESS_EXPIRES', { infer: true }),
        audience: 'farzandim-consumer',
        issuer: 'farzandim-backend',
      },
    );
  }

  private signRefreshToken(payload: JwtPayload): string {
    return this.jwtService.sign(
      { userId: payload.userId, role: payload.role, tokenVersion: payload.tokenVersion },
      {
        secret: this.config.get('JWT_REFRESH_SECRET', { infer: true }),
        expiresIn: this.config.get('JWT_REFRESH_EXPIRES', { infer: true }),
        audience: 'farzandim-consumer',
        issuer: 'farzandim-backend',
      },
    );
  }

  private verifyRefreshToken(token: string): JwtPayload {
    return this.jwtService.verify<JwtPayload>(token, {
      secret: this.config.get('JWT_REFRESH_SECRET', { infer: true }),
      audience: 'farzandim-consumer',
      issuer: 'farzandim-backend',
    });
  }

  /* ------------------------------------------------------------------ */
  /*  Telegram Login                                                     */
  /* ------------------------------------------------------------------ */

  async telegramLogin(
    dto: TelegramAuthDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const data: TelegramAuthData = dto;

    if (!this.telegramService.verifyTelegramAuth(data)) {
      throw new UnauthorizedException('Invalid Telegram hash');
    }

    if (!this.telegramService.isAuthDataFresh(data.auth_date)) {
      throw new UnauthorizedException('Auth data expired');
    }

    const telegramId = String(data.id);
    const displayName =
      [data.first_name, data.last_name].filter(Boolean).join(' ') ||
      data.username ||
      `User${telegramId}`;

    const existing = await this.prisma.user.findUnique({ where: { telegramId } });

    const user = await this.prisma.user.upsert({
      where: { telegramId },
      update: {
        avatarUrl: data.photo_url ?? undefined,
      },
      create: {
        telegramId,
        role: 'PARENT',
        name: displayName,
        avatarUrl: data.photo_url,
      },
    });

    await this.audit.log(
      user.id,
      'auth',
      existing ? 'LOGIN' : 'CREATE',
      user.id,
      { telegramId, method: 'telegram' },
      reqMeta,
    );

    const payload: JwtPayload = {
      userId: user.id,
      role: user.role as 'PARENT' | 'CHILD',
      tokenVersion: user.tokenVersion,
    };
    const accessToken = this.signAccessToken(payload);
    const refreshToken = this.signRefreshToken(payload);

    return {
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
        avatarUrl: user.avatarUrl,
        telegramId: user.telegramId,
        language: user.language,
      },
      accessToken,
      refreshToken,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  Refresh Token (with rotation + tokenVersion check)                 */
  /* ------------------------------------------------------------------ */

  async refreshToken(token: string) {
    let payload: JwtPayload;
    try {
      payload = this.verifyRefreshToken(token);
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.userId },
    });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('User not found or inactive');
    }

    // tokenVersion mismatch means logout was called => reject
    if ((payload.tokenVersion ?? 0) !== user.tokenVersion) {
      throw new UnauthorizedException('Token revoked');
    }

    const newPayload: JwtPayload = {
      userId: user.id,
      role: user.role as 'PARENT' | 'CHILD',
      tokenVersion: user.tokenVersion,
    };

    return {
      accessToken: this.signAccessToken(newPayload),
      refreshToken: this.signRefreshToken(newPayload),
    };
  }

  /* ------------------------------------------------------------------ */
  /*  Child Pair                                                         */
  /* ------------------------------------------------------------------ */

  async childPair(
    dto: ChildPairDto,
    reqMeta?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({
      where: { familyCode: dto.familyCode },
    });
    if (!child) {
      throw new NotFoundException('Family code not found');
    }

    // Re-pair flow: child already paired => need parent confirmation
    if (child.childUserId) {
      // Expire any pending pair requests
      await this.prisma.childPairRequest.updateMany({
        where: {
          childId: child.id,
          status: 'PENDING',
          expiresAt: { gt: new Date() },
        },
        data: { status: 'EXPIRED', decidedAt: new Date() },
      });

      const expiresAt = new Date(Date.now() + PAIR_REQUEST_TTL_MIN * 60 * 1000);

      const pairRequest = await this.prisma.childPairRequest.create({
        data: {
          childId: child.id,
          deviceInfo: (dto.deviceInfo as object) ?? undefined,
          ipAddress: reqMeta?.ip ?? null,
          userAgent:
            (reqMeta?.headers?.['user-agent'] as string | undefined) ?? null,
          expiresAt,
        },
      });

      await this.audit.log(
        null,
        'auth',
        'PAIR',
        pairRequest.id,
        {
          action: 'PAIR_REQUEST_CREATED',
          childId: child.id,
          familyCode: dto.familyCode,
        },
        reqMeta,
      );

      // Realtime + push to parent
      this.realtime.emitToUser(child.parentId, 'pair_request:created', {
        id: pairRequest.id,
        childId: child.id,
        childName: child.name,
        deviceInfo: pairRequest.deviceInfo,
        ipAddress: pairRequest.ipAddress,
        expiresAt: pairRequest.expiresAt.toISOString(),
      });

      try {
        await this.fcm.sendPushToUser(child.parentId, {
          title: `${child.name} — yangi qurilma`,
          body: 'Yangi qurilma family code bilan ulanmoqchi. Tasdiqlang.',
          data: {
            type: 'pair_request',
            pairRequestId: pairRequest.id,
            childId: child.id,
          },
        });
      } catch (err) {
        this.logger.warn(
          { err, pairRequestId: pairRequest.id },
          'pair_request push failed',
        );
      }

      throw new ConflictException({
        error: 'AWAITING_PARENT_CONFIRM',
        message:
          'Bola allaqachon ulangan. Ota-onangiz yangi qurilmani tasdiqlashi kerak.',
        pairRequestId: pairRequest.id,
        expiresAt: pairRequest.expiresAt.toISOString(),
        pollIntervalSec: 3,
      });
    }

    // Fresh pair: create User for child
    const user = await this.prisma.user.create({
      data: {
        role: 'CHILD',
        name: child.name,
      },
    });

    const deviceInfo = dto.deviceInfo;
    const updatedChild = await this.prisma.child.update({
      where: { id: child.id },
      data: {
        childUserId: user.id,
        isConnected: true,
        pairedAt: new Date(),
        ...(deviceInfo?.model && { deviceModel: deviceInfo.model }),
        ...(deviceInfo?.batteryLevel !== undefined && {
          batteryLevel: deviceInfo.batteryLevel,
        }),
        ...(deviceInfo?.isCharging !== undefined && {
          isCharging: deviceInfo.isCharging,
        }),
      },
    });

    const payload: JwtPayload = {
      userId: user.id,
      role: user.role as 'PARENT' | 'CHILD',
      tokenVersion: user.tokenVersion,
    };
    const accessToken = this.signAccessToken(payload);
    const refreshToken = this.signRefreshToken(payload);

    await this.audit.log(
      user.id,
      'auth',
      'PAIR',
      user.id,
      { childId: updatedChild.id, familyCode: dto.familyCode },
      reqMeta,
    );

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
        avatarUrl: user.avatarUrl,
        telegramId: user.telegramId,
        language: user.language,
      },
      child: {
        id: updatedChild.id,
        parentId: updatedChild.parentId,
        name: updatedChild.name,
        age: updatedChild.age,
      },
    };
  }

  /* ------------------------------------------------------------------ */
  /*  Child Pair Status (polling endpoint for re-pair flow)              */
  /* ------------------------------------------------------------------ */

  async childPairStatus(pairRequestId: string) {
    const pairRequest = await this.prisma.childPairRequest.findUnique({
      where: { id: pairRequestId },
    });

    if (!pairRequest) {
      throw new NotFoundException('Pair request not found');
    }

    // Check if expired
    if (
      pairRequest.status === 'PENDING' &&
      pairRequest.expiresAt < new Date()
    ) {
      await this.prisma.childPairRequest.update({
        where: { id: pairRequestId },
        data: { status: 'EXPIRED', decidedAt: new Date() },
      });
      return { status: 'EXPIRED' };
    }

    return { status: pairRequest.status };
  }

  /* ------------------------------------------------------------------ */
  /*  Logout — increment tokenVersion, all refresh tokens become invalid */
  /* ------------------------------------------------------------------ */

  async logout(userId: string): Promise<{ ok: true }> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { tokenVersion: { increment: 1 } },
    });
    return { ok: true };
  }
}
