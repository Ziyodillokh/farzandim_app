import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { NudgeService } from './nudge.service';
import { NotificationPreferencesController } from './notification-preferences.controller';
import { NotificationPreferencesService } from './notification-preferences.service';

/**
 * NudgesModule — rejalashtirilgan ijobiy eslatmalar (#66/#67/#77).
 * NudgeService @Cron (global ScheduleModule), preferences GET/PUT API.
 * PrismaService global, FcmService FcmModule'dan.
 */
@Module({
  imports: [FcmModule],
  controllers: [NotificationPreferencesController],
  providers: [NudgeService, NotificationPreferencesService],
})
export class NudgesModule {}
