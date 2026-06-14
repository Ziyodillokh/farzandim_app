import { Module } from '@nestjs/common';
import { FcmModule } from '../fcm/fcm.module';
import { ConnectionMonitorService } from './connection-monitor.service';

/**
 * ConnectionMonitorModule — "aloqa uzildi" cron (har 3 daqiqada). PrismaService
 * global (DatabaseModule), FcmService FcmModule'dan keladi.
 */
@Module({
  imports: [FcmModule],
  providers: [ConnectionMonitorService],
})
export class ConnectionMonitorModule {}
