import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { FcmService } from '../../common/fcm/fcm.service';
import { CreateSosAlertDto } from './dto/create-sos-alert.dto';
import { ListSosAlertsDto } from './dto/list-sos-alerts.dto';

@Injectable()
export class SosAlertsService {
  private readonly logger = new Logger(SosAlertsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
    private readonly fcm: FcmService,
  ) {}

  async create(
    childId: string,
    userId: string,
    dto: CreateSosAlertDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Child not found');
    if (child.childUserId !== userId && child.parentId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const alert = await this.prisma.sosAlert.create({
      data: {
        childId,
        latitude: dto.latitude,
        longitude: dto.longitude,
        accuracy: dto.accuracy,
        deviceInfo: dto.deviceInfo as object | undefined,
      },
    });

    await this.audit.log(
      userId,
      'sos_alert',
      'CREATE',
      alert.id,
      dto,
      request,
    );

    // Real-time + push -- critical
    this.realtime.emitToUser(child.parentId, 'sos:received', {
      alert,
      childId,
      childName: child.name,
    });
    this.realtime.emitToChild(childId, 'sos:received', { alert });

    // Push xabar matni: aniq, hissiy, harakatga undovchi.
    // Lokatsiya bo'lsa Google Maps havolasi qo'shiladi — tap qilganda
    // ota-ona darhol xaritada bola joylashuvini ko'radi.
    const mapsUrl = alert.latitude && alert.longitude
      ? `https://maps.google.com/?q=${alert.latitude},${alert.longitude}`
      : null;

    const title = `🆘 SOS — ${child.name}`;
    const body = mapsUrl
      ? `${child.name} yordam so'ramoqda! Joriy joylashuv: ${alert.latitude!.toFixed(5)}, ${alert.longitude!.toFixed(5)}`
      : `${child.name} SOS bosdi — joylashuv yo'q. Tezda bog'laning.`;

    try {
      await this.fcm.sendPushToUser(child.parentId, {
        title,
        body,
        data: {
          type: 'sos',
          alertId: alert.id,
          childId,
          childName: child.name,
          priority: 'high',
          ...(alert.latitude !== null && alert.latitude !== undefined
            ? { latitude: String(alert.latitude) }
            : {}),
          ...(alert.longitude !== null && alert.longitude !== undefined
            ? { longitude: String(alert.longitude) }
            : {}),
          ...(alert.accuracy !== null && alert.accuracy !== undefined
            ? { accuracy: String(alert.accuracy) }
            : {}),
          ...(mapsUrl ? { mapsUrl } : {}),
        },
      });
    } catch (err) {
      this.logger.warn(`SOS push failed for alert ${alert.id}`, err);
    }

    return alert;
  }

  async list(userId: string, query: ListSosAlertsDto) {
    const { status, limit } = query;

    const alerts = await this.prisma.sosAlert.findMany({
      where: {
        ...(status && { status }),
        child: {
          OR: [{ parentId: userId }, { childUserId: userId }],
        },
      },
      include: {
        child: {
          select: {
            id: true,
            name: true,
            parentId: true,
            childUserId: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return { alerts, count: alerts.length };
  }

  async resolve(
    id: string,
    userId: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const alert = await this.prisma.sosAlert.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!alert) throw new NotFoundException('SOS alert not found');
    if (alert.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can resolve');
    }
    if (alert.status === 'RESOLVED') {
      return alert;
    }

    const updated = await this.prisma.sosAlert.update({
      where: { id },
      data: {
        status: 'RESOLVED',
        resolvedAt: new Date(),
        resolvedBy: userId,
      },
    });

    await this.audit.log(
      userId,
      'sos_alert',
      'RESOLVE',
      id,
      undefined,
      request,
    );

    // `sos:received` ota-onaga ham, bolaga ham boradi — `sos:resolved` esa
    // faqat bolaga borardi. Shu sabab ota-ona tomonida SOS "hal qilindi"
    // xabari hech qachon kelmasdi: global qizil banner o'z-o'zidan yopilmasdi
    // va ikkinchi qurilmadagi SOS ro'yxati eski holatda qolardi.
    this.realtime.emitToUser(alert.child.parentId, 'sos:resolved', updated);
    if (alert.child.childUserId) {
      this.realtime.emitToUser(
        alert.child.childUserId,
        'sos:resolved',
        updated,
      );
    }
    this.realtime.emitToChild(alert.childId, 'sos:resolved', updated);

    return updated;
  }
}
