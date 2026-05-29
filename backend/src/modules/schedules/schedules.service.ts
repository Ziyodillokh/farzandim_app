import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { CreateScheduleDto } from './dto/create-schedule.dto';
import { UpdateScheduleDto } from './dto/update-schedule.dto';

@Injectable()
export class SchedulesService {
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

    const schedules = await this.prisma.schedule.findMany({
      where: { childId },
      orderBy: { createdAt: 'desc' },
    });

    return { schedules, count: schedules.length };
  }

  async create(
    userId: string,
    childId: string,
    dto: CreateScheduleDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can create schedules');
    }

    if (dto.startTime === dto.endTime) {
      throw new BadRequestException(
        'startTime and endTime must differ (use 00:00-23:59 for full day)',
      );
    }

    // Deduplicate and sort days of week
    const daysOfWeek = Array.from(new Set(dto.daysOfWeek)).sort((a, b) => a - b);

    const schedule = await this.prisma.schedule.create({
      data: {
        childId,
        name: dto.name,
        startTime: dto.startTime,
        endTime: dto.endTime,
        daysOfWeek,
        action: dto.action,
        isActive: dto.isActive ?? true,
      },
    });

    await this.audit.log(userId, 'schedule', 'CREATE', schedule.id, dto, request);
    this.realtime.emitToChild(childId, 'schedule:created', schedule);

    return schedule;
  }

  async findOne(userId: string, id: string) {
    const schedule = await this.prisma.schedule.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!schedule) throw new NotFoundException('Schedule not found');
    if (schedule.child.parentId !== userId && schedule.child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const { child: _omit, ...rest } = schedule;
    return rest;
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateScheduleDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const schedule = await this.prisma.schedule.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!schedule) throw new NotFoundException('Schedule not found');
    if (schedule.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can update schedules');
    }

    const nextStart = dto.startTime ?? schedule.startTime;
    const nextEnd = dto.endTime ?? schedule.endTime;
    if (nextStart === nextEnd) {
      throw new BadRequestException(
        'startTime and endTime must differ (use 00:00-23:59 for full day)',
      );
    }

    // Deduplicate and sort if provided
    const data: any = { ...dto };
    if (dto.daysOfWeek) {
      data.daysOfWeek = Array.from(new Set(dto.daysOfWeek)).sort((a, b) => a - b);
    }

    const updated = await this.prisma.schedule.update({
      where: { id },
      data,
    });

    await this.audit.log(userId, 'schedule', 'UPDATE', id, dto, request);
    this.realtime.emitToChild(updated.childId, 'schedule:updated', updated);

    return updated;
  }

  async remove(
    userId: string,
    id: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const schedule = await this.prisma.schedule.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!schedule) throw new NotFoundException('Schedule not found');
    if (schedule.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can delete schedules');
    }

    const childIdForEmit = schedule.childId;
    await this.prisma.schedule.delete({ where: { id } });
    await this.audit.log(userId, 'schedule', 'DELETE', id, undefined, request);
    this.realtime.emitToChild(childIdForEmit, 'schedule:deleted', { id });

    return { ok: true };
  }
}
