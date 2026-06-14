import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';

@Injectable()
export class NotificationPreferencesService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertAccess(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({ where: { id: childId } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) {
      throw new ForbiddenException('Forbidden');
    }
    return child;
  }

  private serialize(p: {
    studyNudge: boolean;
    healthNudge: boolean;
    contentReminder: boolean;
    quietFrom: string | null;
    quietTo: string | null;
  }) {
    return {
      studyNudge: p.studyNudge,
      healthNudge: p.healthNudge,
      contentReminder: p.contentReminder,
      quietFrom: p.quietFrom,
      quietTo: p.quietTo,
    };
  }

  /** Sozlamalarni o'qish — yozuv yo'q bo'lsa default (hammasi yoqilgan). */
  async get(childId: string, userId: string) {
    await this.assertAccess(childId, userId);
    const pref = await this.prisma.notificationPreference.findUnique({
      where: { childId },
    });
    return this.serialize(
      pref ?? {
        studyNudge: true,
        healthNudge: true,
        contentReminder: true,
        quietFrom: null,
        quietTo: null,
      },
    );
  }

  /** Sozlamalarni yangilash (upsert). */
  async update(childId: string, userId: string, dto: UpdatePreferencesDto) {
    await this.assertAccess(childId, userId);
    const data = {
      ...(dto.studyNudge !== undefined && { studyNudge: dto.studyNudge }),
      ...(dto.healthNudge !== undefined && { healthNudge: dto.healthNudge }),
      ...(dto.contentReminder !== undefined && {
        contentReminder: dto.contentReminder,
      }),
      ...(dto.quietFrom !== undefined && { quietFrom: dto.quietFrom }),
      ...(dto.quietTo !== undefined && { quietTo: dto.quietTo }),
    };
    const pref = await this.prisma.notificationPreference.upsert({
      where: { childId },
      create: { childId, ...data },
      update: data,
    });
    return this.serialize(pref);
  }
}
