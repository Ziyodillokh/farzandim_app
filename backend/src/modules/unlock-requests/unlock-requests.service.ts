import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationType, UnlockRequest } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { FcmService } from '../../common/fcm/fcm.service';
import { CreateUnlockRequestDto } from './dto/create-unlock-request.dto';
import { DecideUnlockRequestDto } from './dto/decide-unlock-request.dto';

/** PENDING so'rov shu muddatda javob kelmasa EXPIRED bo'ladi. */
const REQUEST_TTL_MS = 15 * 60 * 1000;

@Injectable()
export class UnlockRequestsService {
  private readonly logger = new Logger(UnlockRequestsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeGateway,
    private readonly fcm: FcmService,
  ) {}

  /** REST javobi uchun — sanalarni ISO va active grant uchun qolgan sekund. */
  private serialize(r: UnlockRequest) {
    const now = Date.now();
    const remainingSeconds =
      r.status === 'APPROVED'
        ? Math.max(0, Math.round((r.expiresAt.getTime() - now) / 1000))
        : 0;
    return {
      id: r.id,
      childId: r.childId,
      packageName: r.packageName,
      kind: r.kind,
      status: r.status,
      requestedMinutes: r.requestedMinutes,
      reason: r.reason,
      grantedMinutes: r.grantedMinutes,
      requestedAt: r.requestedAt.toISOString(),
      decidedAt: r.decidedAt ? r.decidedAt.toISOString() : null,
      expiresAt: r.expiresAt.toISOString(),
      remainingSeconds,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /unlock-requests — BOLA qo'shimcha vaqt so'raydi              */
  /* ------------------------------------------------------------------ */
  async create(userId: string, dto: CreateUnlockRequestDto) {
    const child = await this.prisma.child.findFirst({
      where: { childUserId: userId },
      select: { id: true, name: true, parentId: true },
    });
    if (!child) {
      throw new ForbiddenException('Only a paired child device can request');
    }
    if (dto.kind === 'APP' && !dto.packageName) {
      throw new BadRequestException('packageName is required for kind=APP');
    }

    const packageName = dto.kind === 'APP' ? dto.packageName! : null;
    const now = new Date();

    // Spam/dublikat yo'q: shu ilova/ekran-vaqt uchun ochiq (PENDING, hali
    // tugamagan) so'rov bo'lsa — yangi yaratmaymiz, mavjudini qaytaramiz.
    const existing = await this.prisma.unlockRequest.findFirst({
      where: {
        childId: child.id,
        kind: dto.kind,
        packageName,
        status: 'PENDING',
        expiresAt: { gt: now },
      },
    });
    if (existing) return this.serialize(existing);

    // Bola so'ragan vaqt (5..60) va sabab — ota-onaga ko'rsatiladi.
    const requestedMinutes = dto.requestedMinutes ?? null;
    const reason = dto.reason?.trim() ? dto.reason.trim() : null;

    const request = await this.prisma.unlockRequest.create({
      data: {
        childId: child.id,
        kind: dto.kind,
        packageName,
        status: 'PENDING',
        requestedMinutes,
        reason,
        expiresAt: new Date(now.getTime() + REQUEST_TTL_MS),
      },
    });

    // Ota-onaga push + bildirishnoma yozuvi.
    const appLabel = packageName
      ? (
          await this.prisma.installedApp.findFirst({
            where: { childId: child.id, packageName },
            select: { appName: true },
          })
        )?.appName ?? packageName
      : null;
    // Spec: "{ilova} uchun {N} daqiqa limit so'rayapti" — so'ralgan vaqt
    // bo'lsa matnga qo'shamiz (title = bola ismi).
    const minutesPart = requestedMinutes ? ` ${requestedMinutes} daqiqa` : '';
    const body =
      dto.kind === 'APP'
        ? `${appLabel} uchun${minutesPart} qo'shimcha vaqt so'rayapti.`
        : `Qo'shimcha ekran vaqti${minutesPart} so'rayapti.`;

    void this.fcm
      .sendPushToUser(child.parentId, {
        title: child.name,
        body,
        data: {
          type: 'unlock_request',
          unlockRequestId: request.id,
          childId: child.id,
          childName: child.name,
          kind: dto.kind,
          ...(packageName ? { packageName } : {}),
          ...(appLabel ? { appName: appLabel } : {}),
          ...(requestedMinutes
            ? { requestedMinutes: String(requestedMinutes) }
            : {}),
          ...(reason ? { reason } : {}),
        },
      })
      .catch((err) => this.logger.warn({ err }, 'unlock_request push failed'));

    await this.prisma.notification.create({
      data: {
        childId: child.id,
        type: NotificationType.UNLOCK_REQUEST,
        title: child.name,
        body,
        data: {
          type: 'unlock_request',
          unlockRequestId: request.id,
          kind: dto.kind,
          ...(packageName ? { packageName } : {}),
          ...(appLabel ? { appName: appLabel } : {}),
          ...(requestedMinutes ? { requestedMinutes } : {}),
          ...(reason ? { reason } : {}),
        },
      },
    });

    // Bola room'i (boshqa bola qurilmalari) + ota-ona user room'i (ekran
    // ochiq turganda yangi PENDING jonli ko'rinsin).
    const payload = this.serialize(request);
    this.realtime.emitToChild(child.id, 'unlock_request:created', payload);
    this.realtime.emitToUser(child.parentId, 'unlock_request:created', payload);
    return payload;
  }

  /* ------------------------------------------------------------------ */
  /*  GET /unlock-requests?status= — OTA-ONA ro'yxati                    */
  /* ------------------------------------------------------------------ */
  async listForParent(userId: string, status?: string) {
    // Avval eskirgan PENDING'larni EXPIRED qilamiz (lazy), ota-ona stale
    // ko'rmasin.
    await this.expireStale();

    const children = await this.prisma.child.findMany({
      where: { parentId: userId },
      select: { id: true },
    });
    const childIds = children.map((c) => c.id);
    if (childIds.length === 0) return { requests: [], count: 0 };

    const requests = await this.prisma.unlockRequest.findMany({
      where: {
        childId: { in: childIds },
        ...(status ? { status: status.toUpperCase() } : {}),
      },
      orderBy: { requestedAt: 'desc' },
      take: 100,
    });
    return {
      requests: requests.map((r) => this.serialize(r)),
      count: requests.length,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  GET /unlock-requests/active — BOLA hozir amal qilayotgan grantlar  */
  /* ------------------------------------------------------------------ */
  async listActiveGrants(userId: string) {
    const child = await this.prisma.child.findFirst({
      where: { childUserId: userId },
      select: { id: true },
    });
    if (!child) throw new ForbiddenException('Only a paired child device');

    const now = new Date();
    const grants = await this.prisma.unlockRequest.findMany({
      where: { childId: child.id, status: 'APPROVED', expiresAt: { gt: now } },
      orderBy: { expiresAt: 'desc' },
    });
    return {
      grants: grants.map((r) => this.serialize(r)),
      count: grants.length,
    };
  }

  /* ------------------------------------------------------------------ */
  /*  POST /unlock-requests/:id/decide — OTA-ONA qaror beradi            */
  /* ------------------------------------------------------------------ */
  async decide(id: string, userId: string, dto: DecideUnlockRequestDto) {
    const request = await this.prisma.unlockRequest.findUnique({
      where: { id },
      include: {
        child: {
          select: { id: true, name: true, parentId: true, childUserId: true },
        },
      },
    });
    if (!request) throw new NotFoundException('Unlock request not found');
    if (request.child.parentId !== userId) {
      throw new ForbiddenException('Only the parent can decide');
    }

    const now = new Date();
    if (request.status !== 'PENDING') {
      throw new BadRequestException(`Request already ${request.status.toLowerCase()}`);
    }
    if (request.expiresAt.getTime() < now.getTime()) {
      await this.prisma.unlockRequest.update({
        where: { id },
        data: { status: 'EXPIRED' },
      });
      throw new BadRequestException('Request already expired');
    }

    if (dto.approve && (dto.minutes === undefined || dto.minutes === null)) {
      throw new BadRequestException('minutes (5..60) is required to approve');
    }

    const approved = dto.approve;
    const grantedMinutes = approved ? dto.minutes! : null;
    // APPROVED bo'lsa ruxsat shu vaqtgacha amal qiladi (qaror + grantedMinutes).
    const expiresAt = approved
      ? new Date(now.getTime() + grantedMinutes! * 60_000)
      : request.expiresAt;

    const updated = await this.prisma.unlockRequest.update({
      where: { id },
      data: {
        status: approved ? 'APPROVED' : 'DENIED',
        grantedMinutes,
        decidedAt: now,
        expiresAt,
      },
    });

    // Bolaga qaror push'i + bildirishnoma.
    const body = approved
      ? `Ota-onangiz ${grantedMinutes} daqiqa qo'shimcha vaqt berdi.`
      : "Ota-onangiz so'rovni rad etdi.";

    // Push bolaning USER hisobiga boradi (childUserId — FcmToken shu bo'yicha).
    if (request.child.childUserId) {
      void this.fcm
        .sendPushToUser(request.child.childUserId, {
          title: 'Parvoz',
          body,
          // data to'liq — ilova fonda bo'lsa ham bola limitни qayta sync qiladi.
          data: {
            type: 'unlock_decision',
            unlockRequestId: updated.id,
            childId: request.child.id,
            kind: updated.kind,
            approved: approved ? 'true' : 'false',
            ...(grantedMinutes !== null
              ? { grantedMinutes: String(grantedMinutes) }
              : {}),
            ...(updated.packageName ? { packageName: updated.packageName } : {}),
          },
        })
        .catch((err) => this.logger.warn({ err }, 'unlock_decision push failed'));
    }

    await this.prisma.notification.create({
      data: {
        childId: request.child.id,
        type: NotificationType.UNLOCK_DECISION,
        title: 'Parvoz',
        body,
        data: {
          type: 'unlock_decision',
          unlockRequestId: updated.id,
          approved,
          ...(grantedMinutes !== null ? { grantedMinutes } : {}),
          ...(updated.packageName ? { packageName: updated.packageName } : {}),
        },
      },
    });

    // Bolaning limit sync'i darhol yangilansin (WS) — grant kunlik limitga
    // qo'shiladi (app-limits.list augmentatsiyasi orqali).
    const decidedPayload = this.serialize(updated);
    this.realtime.emitToChild(request.child.id, 'unlock_request:decided', decidedPayload);
    this.realtime.emitToChild(request.child.id, 'app_limit:updated', { reason: 'unlock' });
    // Ota-onaning boshqa qurilmalari ham qaror natijasini ko'rsin (so'rov
    // ro'yxatdan chiqsin / status yangilansin).
    this.realtime.emitToUser(request.child.parentId, 'unlock_request:decided', decidedPayload);

    return decidedPayload;
  }

  /* ------------------------------------------------------------------ */
  /*  Cron — eskirgan PENDING'larni EXPIRED qiladi (har 5 daqiqada)      */
  /* ------------------------------------------------------------------ */
  @Cron('0 */5 * * * *', { name: 'unlock-requests-expire' })
  async expireStale(): Promise<void> {
    const res = await this.prisma.unlockRequest.updateMany({
      where: { status: 'PENDING', expiresAt: { lt: new Date() } },
      data: { status: 'EXPIRED' },
    });
    if (res.count > 0) {
      this.logger.log(`unlock-requests: expired ${res.count} pending`);
    }
  }
}
