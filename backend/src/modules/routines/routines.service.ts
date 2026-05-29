import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { tashkentNow, isActiveNow } from '../../common/helpers/routines-rules';
import { CreateRoutineDto } from './dto/create-routine.dto';
import { UpdateRoutineDto } from './dto/update-routine.dto';

@Injectable()
export class RoutinesService {
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

    const routines = await this.prisma.routine.findMany({
      where: { childId },
      orderBy: [{ startHour: 'asc' }, { startMinute: 'asc' }],
    });

    return { routines, count: routines.length };
  }

  async getToday(userId: string, childId: string) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const { isoWeekday, totalMinutes, hour, minute } = tashkentNow();

    const todayRoutines = await this.prisma.routine.findMany({
      where: {
        childId,
        isActive: true,
        weekdays: { has: isoWeekday },
      },
      orderBy: [{ startHour: 'asc' }, { startMinute: 'asc' }],
    });

    // Find current active routine
    let current: (typeof todayRoutines)[number] | null = null;
    for (const r of todayRoutines) {
      if (isActiveNow(r, totalMinutes)) {
        current = r;
        break;
      }
    }

    // Find next routine starting after now (today)
    let next: ((typeof todayRoutines)[number] & { startsInMinutes: number }) | null = null;
    let bestDelta = Infinity;
    for (const r of todayRoutines) {
      const startMin = r.startHour * 60 + r.startMinute;
      if (startMin > totalMinutes) {
        const delta = startMin - totalMinutes;
        if (delta < bestDelta) {
          bestDelta = delta;
          next = { ...r, startsInMinutes: delta };
        }
      }
    }

    return {
      today: todayRoutines,
      current,
      next,
      serverTime: {
        isoWeekday,
        hour,
        minute,
        timezone: 'Asia/Tashkent',
      },
    };
  }

  async create(
    userId: string,
    childId: string,
    dto: CreateRoutineDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Only parent can create routines');
    }

    const startMin = dto.startHour * 60 + dto.startMinute;
    const endMin = dto.endHour * 60 + dto.endMinute;
    if (startMin === endMin) {
      throw new BadRequestException('start and end must differ');
    }

    // Deduplicate and sort weekdays
    const weekdays = Array.from(new Set(dto.weekdays)).sort((a, b) => a - b);

    const routine = await this.prisma.routine.create({
      data: {
        childId,
        title: dto.title,
        type: dto.type,
        startHour: dto.startHour,
        startMinute: dto.startMinute,
        endHour: dto.endHour,
        endMinute: dto.endMinute,
        weekdays,
        isActive: dto.isActive ?? true,
      },
    });

    await this.audit.log(userId, 'routine', 'CREATE', routine.id, dto, request);
    this.realtime.emitToChild(childId, 'routine:created', routine);

    return routine;
  }

  async findOne(userId: string, id: string) {
    const routine = await this.prisma.routine.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!routine) throw new NotFoundException('Routine not found');
    if (routine.child.parentId !== userId && routine.child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const { child: _omit, ...rest } = routine;
    return rest;
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateRoutineDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const routine = await this.prisma.routine.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!routine) throw new NotFoundException('Routine not found');
    if (routine.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can update routines');
    }

    const nextStartMin =
      (dto.startHour ?? routine.startHour) * 60 +
      (dto.startMinute ?? routine.startMinute);
    const nextEndMin =
      (dto.endHour ?? routine.endHour) * 60 +
      (dto.endMinute ?? routine.endMinute);
    if (nextStartMin === nextEndMin) {
      throw new BadRequestException('start and end must differ');
    }

    // Deduplicate and sort if provided
    const data: any = { ...dto };
    if (dto.weekdays) {
      data.weekdays = Array.from(new Set(dto.weekdays)).sort((a, b) => a - b);
    }

    const updated = await this.prisma.routine.update({
      where: { id },
      data,
    });

    await this.audit.log(userId, 'routine', 'UPDATE', id, dto, request);
    this.realtime.emitToChild(updated.childId, 'routine:updated', updated);

    return updated;
  }

  async remove(
    userId: string,
    id: string,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const routine = await this.prisma.routine.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!routine) throw new NotFoundException('Routine not found');
    if (routine.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can delete routines');
    }

    const childIdForEmit = routine.childId;
    await this.prisma.routine.delete({ where: { id } });
    await this.audit.log(userId, 'routine', 'DELETE', id, undefined, request);
    this.realtime.emitToChild(childIdForEmit, 'routine:deleted', { id });

    return { ok: true };
  }
}
