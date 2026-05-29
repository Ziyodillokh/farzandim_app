import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { AuditService } from '../../common/audit/audit.service';
import { RealtimeGateway } from '../../common/realtime/realtime.gateway';
import { CreateFeedbackDto } from './dto/create-feedback.dto';
import { ListFeedbackDto } from './dto/list-feedback.dto';

@Injectable()
export class FeedbackService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async listByChild(userId: string, childId: string, query: ListFeedbackDto) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const limit = query.limit ?? 100;

    const feedback = await this.prisma.feedback.findMany({
      where: {
        childId,
        ...(query.isRead !== undefined ? { isRead: query.isRead === 'true' } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return { feedback, count: feedback.length };
  }

  async create(
    userId: string,
    childId: string,
    dto: CreateFeedbackDto,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.childUserId !== userId && child.parentId !== userId) {
      throw new ForbiddenException('Forbidden');
    }

    const feedback = await this.prisma.feedback.create({
      data: {
        childId,
        emoji: dto.emoji,
        message: dto.message,
        context: dto.context,
      },
    });

    await this.audit.log(userId, 'feedback', 'CREATE', feedback.id, dto, request);

    // Real-time: notify parent about new feedback
    this.realtime.emitToUser(child.parentId, 'feedback:received', feedback);
    this.realtime.emitToChild(childId, 'feedback:created', feedback);

    return feedback;
  }

  async markAsRead(userId: string, id: string) {
    const feedback = await this.prisma.feedback.findUnique({
      where: { id },
      include: { child: true },
    });
    if (!feedback) throw new NotFoundException('Feedback not found');
    if (feedback.child.parentId !== userId) {
      throw new ForbiddenException('Only parent can mark feedback as read');
    }

    return this.prisma.feedback.update({
      where: { id },
      data: { isRead: true },
    });
  }
}
