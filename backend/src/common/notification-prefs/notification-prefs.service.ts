// Bola sozlamalarini o'qish (yozuv yo'q bo'lsa — standart). Push yuboruvchi servislar uchun umumiy.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { resolvePrefs, ResolvedPrefs } from './notification-prefs';

@Injectable()
export class NotificationPrefsService {
  constructor(private readonly prisma: PrismaService) {}

  async forChild(childId: string): Promise<ResolvedPrefs> {
    const row = await this.prisma.notificationPreference.findUnique({ where: { childId } });
    return resolvePrefs(row);
  }
}
