import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { PairRequestStatus } from './dto/list-pair-requests.dto';

@Injectable()
export class ChildPairRequestsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
  ) {}

  /** Lazy expiration: if PENDING and past expiresAt, mark as EXPIRED. */
  private async checkExpiration(
    reqRow: {
      id: string;
      status: string;
      expiresAt: Date;
    },
  ): Promise<string> {
    if (reqRow.status === 'PENDING' && reqRow.expiresAt < new Date()) {
      await this.prisma.childPairRequest.update({
        where: { id: reqRow.id },
        data: { status: 'EXPIRED', decidedAt: new Date() },
      });
      return 'EXPIRED';
    }
    return reqRow.status;
  }

  async list(childId: string, userId: string, statusFilter?: PairRequestStatus) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can view pair requests');
    }

    const requests = await this.prisma.childPairRequest.findMany({
      where: { childId, ...(statusFilter && { status: statusFilter }) },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    return { requests, count: requests.length };
  }

  async approve(
    childId: string,
    id: string,
    userId: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const pairReq = await this.prisma.childPairRequest.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!pairReq || pairReq.childId !== childId) {
      throw new NotFoundException('Pair request not found');
    }
    if (pairReq.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can approve');
    }

    const status = await this.checkExpiration(pairReq);
    if (status !== 'PENDING') {
      throw new ConflictException(`Pair request is ${status}`);
    }

    // Transactional re-pair
    const result = await this.prisma.$transaction(async (tx) => {
      const oldChildUserId = pairReq.child.childUserId;

      // "Bir bola = bir qurilma" qoidasi: eski qurilmani majburan chiqarish.
      //   - userSession revoke → barcha aktiv refresh tokenlar bekor
      //   - tokenVersion++ → refreshToken (auth.service tekshiruvi) ham
      //     darhol ishlamaydi (access token 15 daqiqada o'ladi)
      //   - isActive=false → keyingi login/refresh urinishlari rad etiladi
      //   - fcmToken o'chirildi → eski qurilmaga push xabarlar bormaydi
      if (oldChildUserId) {
        await tx.userSession.updateMany({
          where: { userId: oldChildUserId, revokedAt: null },
          data: { revokedAt: new Date() },
        });
        await tx.user.update({
          where: { id: oldChildUserId },
          data: {
            isActive: false,
            tokenVersion: { increment: 1 },
          },
        });
        await tx.fcmToken.deleteMany({ where: { userId: oldChildUserId } });
      }

      // Create new user for child
      const newUser = await tx.user.create({
        data: { role: 'CHILD', name: pairReq.child.name },
      });

      // Device info from pair request
      const deviceInfo = (pairReq.deviceInfo ?? {}) as {
        model?: string;
        batteryLevel?: number;
        isCharging?: boolean;
      };

      await tx.child.update({
        where: { id: childId },
        data: {
          childUserId: newUser.id,
          isConnected: true,
          pairedAt: new Date(),
          ...(deviceInfo.model && { deviceModel: deviceInfo.model }),
          ...(deviceInfo.batteryLevel !== undefined && {
            batteryLevel: deviceInfo.batteryLevel,
          }),
          ...(deviceInfo.isCharging !== undefined && {
            isCharging: deviceInfo.isCharging,
          }),
        },
      });

      await tx.childPairRequest.update({
        where: { id },
        data: {
          status: 'APPROVED',
          decidedAt: new Date(),
          newUserId: newUser.id,
        },
      });

      return { newUser, oldChildUserId };
    });

    await this.audit.log(
      userId,
      'auth',
      'PAIR',
      id,
      {
        action: 'PAIR_REQUEST_APPROVED',
        childId,
        newUserId: result.newUser.id,
        oldChildUserId: result.oldChildUserId,
      },
      request,
    );

    this.realtime.emitToUser(userId, 'pair_request:approved', {
      id,
      childId,
      newUserId: result.newUser.id,
    });

    // Eski bola qurilmasiga "siz unpair bo'ldingiz" signali — UI darhol
    // lokal ma'lumotlarni tozalab, qayta kod kiritish ekraniga qaytadi.
    // Ovozi/lokatsiya foreground service'lari ham to'xtab, eski telefon
    // bola profiliga kirishni davom ettira olmaydi.
    if (result.oldChildUserId) {
      this.realtime.emitToUser(result.oldChildUserId, 'child:unpaired', {
        childId,
        reason: 'NEW_DEVICE_APPROVED',
        at: new Date().toISOString(),
      });
    }

    return {
      ok: true,
      status: 'APPROVED',
      pairRequestId: id,
      newUserId: result.newUser.id,
    };
  }

  async reject(
    childId: string,
    id: string,
    userId: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const pairReq = await this.prisma.childPairRequest.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!pairReq || pairReq.childId !== childId) {
      throw new NotFoundException('Pair request not found');
    }
    if (pairReq.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can reject');
    }

    const status = await this.checkExpiration(pairReq);
    if (status !== 'PENDING') {
      throw new ConflictException(`Pair request is ${status}`);
    }

    await this.prisma.childPairRequest.update({
      where: { id },
      data: { status: 'REJECTED', decidedAt: new Date() },
    });

    await this.audit.log(
      userId,
      'auth',
      'PAIR',
      id,
      { action: 'PAIR_REQUEST_REJECTED', childId },
      request,
    );

    this.realtime.emitToUser(userId, 'pair_request:rejected', { id, childId });

    return { ok: true, status: 'REJECTED' };
  }
}
