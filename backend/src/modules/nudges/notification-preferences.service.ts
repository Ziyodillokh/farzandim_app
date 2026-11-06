import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import {
  isValidReminderTime,
  REMINDER_TIME_MAX,
  REMINDER_TIME_MIN,
  resolvePrefs,
} from '../../common/notification-prefs/notification-prefs';
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

  /** Sozlamalarni o'qish — yozuv yo'q bo'lsa default (hammasi yoqilgan, kunlik eslatma 18:00, matn yashirilmagan). */
  async get(childId: string, userId: string) {
    await this.assertAccess(childId, userId);
    const pref = await this.prisma.notificationPreference.findUnique({
      where: { childId },
    });
    return resolvePrefs(pref);
  }

  /** Sozlamalarni yangilash (upsert, qisman). */
  async update(childId: string, userId: string, dto: UpdatePreferencesDto) {
    await this.assertAccess(childId, userId);
    if (dto.dailyReminderTime !== undefined && !isValidReminderTime(dto.dailyReminderTime)) {
      throw new BadRequestException({
        code: 'VALIDATION',
        message: `dailyReminderTime HH:MM formatida va ${REMINDER_TIME_MIN}–${REMINDER_TIME_MAX} oralig'ida bo'lishi kerak`,
      });
    }
    const data = {
      ...(dto.studyNudge !== undefined && { studyNudge: dto.studyNudge }),
      ...(dto.healthNudge !== undefined && { healthNudge: dto.healthNudge }),
      ...(dto.contentReminder !== undefined && {
        contentReminder: dto.contentReminder,
      }),
      ...(dto.quietFrom !== undefined && { quietFrom: dto.quietFrom }),
      ...(dto.quietTo !== undefined && { quietTo: dto.quietTo }),
      ...(dto.homeworkReminder !== undefined && { homeworkReminder: dto.homeworkReminder }),
      ...(dto.schoolAnnouncements !== undefined && { schoolAnnouncements: dto.schoolAnnouncements }),
      ...(dto.familyMessages !== undefined && { familyMessages: dto.familyMessages }),
      ...(dto.dailyReminder !== undefined && { dailyReminder: dto.dailyReminder }),
      ...(dto.dailyReminderTime !== undefined && { dailyReminderTime: dto.dailyReminderTime }),
      ...(dto.hideText !== undefined && { hideText: dto.hideText }),
    };
    const pref = await this.prisma.notificationPreference.upsert({
      where: { childId },
      create: { childId, ...data },
      update: data,
    });
    return resolvePrefs(pref);
  }
}
