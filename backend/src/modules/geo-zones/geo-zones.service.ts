import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { CreateGeoZoneDto } from './dto/create-geo-zone.dto';
import { UpdateGeoZoneDto } from './dto/update-geo-zone.dto';
import { ListGeoZoneEventsDto } from './dto/list-geo-zone-events.dto';

@Injectable()
export class GeoZonesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async listByChild(userId: string, childId: string) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const zones = await this.prisma.geoZone.findMany({
      where: { childId },
      orderBy: { createdAt: 'desc' },
    });

    return { zones, count: zones.length };
  }

  async create(
    userId: string,
    childId: string,
    dto: CreateGeoZoneDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can create geo-zones');
    }

    const zone = await this.prisma.geoZone.create({
      data: {
        childId,
        name: dto.name,
        centerLat: dto.centerLat,
        centerLng: dto.centerLng,
        radiusMeters: dto.radiusMeters,
        alertOnEnter: dto.alertOnEnter ?? false,
        alertOnExit: dto.alertOnExit ?? false,
        isActive: dto.isActive ?? true,
      },
    });

    await this.audit.log(userId, 'geo_zone', 'CREATE', zone.id, dto, request);
    this.realtime.emitToChild(childId, 'geo_zone:created', zone);

    return zone;
  }

  async findOne(userId: string, id: string) {
    const zone = await this.prisma.geoZone.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!zone) throw new NotFoundException('Geo-zone not found');
    if (zone.child.parentId !== userId && zone.child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const { child: _omit, ...rest } = zone;
    return rest;
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateGeoZoneDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const zone = await this.prisma.geoZone.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!zone) throw new NotFoundException('Geo-zone not found');
    if (zone.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can update geo-zones');
    }

    const updated = await this.prisma.geoZone.update({
      where: { id },
      data: dto,
    });

    await this.audit.log(userId, 'geo_zone', 'UPDATE', id, dto, request);
    this.realtime.emitToChild(updated.childId, 'geo_zone:updated', updated);

    return updated;
  }

  async remove(
    userId: string,
    id: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const zone = await this.prisma.geoZone.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!zone) throw new NotFoundException('Geo-zone not found');
    if (zone.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can delete geo-zones');
    }

    const childIdForEmit = zone.childId;
    await this.prisma.geoZone.delete({ where: { id } });
    await this.audit.log(userId, 'geo_zone', 'DELETE', id, undefined, request);
    this.realtime.emitToChild(childIdForEmit, 'geo_zone:deleted', { id });

    return { ok: true };
  }

  async listEvents(userId: string, childId: string, query: ListGeoZoneEventsDto) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const limit = query.limit ?? 50;

    const events = await this.prisma.geoZoneEvent.findMany({
      where: {
        childId,
        createdAt: {
          ...(query.from ? { gte: new Date(query.from) } : {}),
          ...(query.to ? { lte: new Date(query.to) } : {}),
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: { zone: { select: { name: true } } },
    });

    return {
      events: events.map((e) => ({
        id: e.id,
        zoneId: e.zoneId,
        zoneName: e.zone.name,
        type: e.type,
        latitude: e.latitude,
        longitude: e.longitude,
        createdAt: e.createdAt.toISOString(),
      })),
      count: events.length,
    };
  }
}
