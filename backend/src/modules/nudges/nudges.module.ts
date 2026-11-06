import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { NotificationPrefsModule } from '../../common/notification-prefs/notification-prefs.module';
import { DailyReminderService } from './daily-reminder.service';
import { NudgeService } from './nudge.service';
import { NotificationPreferencesController } from './notification-preferences.controller';
import { NotificationPreferencesService } from './notification-preferences.service';

/**
 * NudgesModule — rejalashtirilgan ijobiy eslatmalar (#66/#67/#77).
 * NudgeService (soatlik) va DailyReminderService (bola belgilagan vaqtda) @Cron (global ScheduleModule), preferences GET/PUT API.
 * PrismaService global, FcmService FcmModule'dan.
 */
@Module({
  imports: [FcmModule, NotificationPrefsModule],
  controllers: [NotificationPreferencesController],
  providers: [NudgeService, DailyReminderService, NotificationPreferencesService],
})
export class NudgesModule {}
