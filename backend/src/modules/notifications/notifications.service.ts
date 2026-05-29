import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { ListNotificationsDto } from './dto/list-notifications.dto';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async listByChild(userId: string, childId: string, query: ListNotificationsDto) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const limit = query.limit ?? 100;

    const notifications = await this.prisma.notification.findMany({
      where: {
        childId,
        ...(query.type ? { type: query.type } : {}),
        ...(query.isRead !== undefined ? { isRead: query.isRead === 'true' } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    const unreadCount = await this.prisma.notification.count({
      where: { childId, isRead: false },
    });

    return { notifications, count: notifications.length, unreadCount };
  }

  async create(
    userId: string,
    childId: string,
    dto: CreateNotificationDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can create notifications');
    }

    const notification = await this.prisma.notification.create({
      data: {
        childId,
        type: dto.type,
        title: dto.title,
        body: dto.body,
        data: dto.data as object | undefined,
      },
    });

    await this.audit.log(userId, 'notification', 'CREATE', notification.id, dto, request);
    this.realtime.emitToChild(childId, 'notification:created', notification);

    return notification;
  }

  async markAsRead(userId: string, id: string) {
    const notification = await this.prisma.notification.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!notification) throw new NotFoundException('Notification not found');
    if (notification.child.parentId !== userId && notification.child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const updated = await this.prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });

    // Sprint 6 P2: admin broadcast first open tracking
    if (notification.adminNotificationId && !notification.isRead) {
      await this.prisma.adminNotification
        .update({
          where: { id: notification.adminNotificationId },
          data: { openedCount: { increment: 1 } },
        })
        .catch(() => {
          /* admin broadcast may have been deleted */
        });
    }

    this.realtime.emitToChild(notification.childId, 'notification:read', { id });

    return updated;
  }

  async click(userId: string, id: string) {
    const notification = await this.prisma.notification.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!notification) throw new NotFoundException('Notification not found');
    if (notification.child.parentId !== userId && notification.child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    // Only count first click
    if (notification.clickedAt === null) {
      await this.prisma.notification.update({
        where: { id },
        data: { clickedAt: new Date() },
      });
      if (notification.adminNotificationId) {
        await this.prisma.adminNotification
          .update({
            where: { id: notification.adminNotificationId },
            data: { clickedCount: { increment: 1 } },
          })
          .catch(() => {
            /* admin broadcast may have been deleted */
          });
      }
    }

    return { ok: true };
  }

  async readAll(userId: string, childId: string) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const result = await this.prisma.notification.updateMany({
      where: { childId, isRead: false },
      data: { isRead: true },
    });

    this.realtime.emitToChild(childId, 'notification:read-all', { count: result.count });

    return { ok: true, updated: result.count };
  }

  async remove(
    userId: string,
    id: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const notification = await this.prisma.notification.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!notification) throw new NotFoundException('Notification not found');
    if (notification.child.parentId !== userId && notification.child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    await this.prisma.notification.delete({ where: { id } });
    await this.audit.log(userId, 'notification', 'DELETE', id, undefined, request);
    this.realtime.emitToChild(notification.childId, 'notification:deleted', { id });

    return { ok: true };
  }
}
