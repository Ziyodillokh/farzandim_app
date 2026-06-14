import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { UnlockRequestsController } from './unlock-requests.controller';
import { UnlockRequestsService } from './unlock-requests.service';

/**
 * UnlockRequestsModule — bola "qo'shimcha vaqt" so'rovi oqimi. PrismaService
 * global (DatabaseModule). FcmModule push uchun, RealtimeModule WS uchun.
 * @Cron (expireStale) global ScheduleModule (app.module) bilan ishlaydi.
 */
@Module({
  imports: [FcmModule, RealtimeModule],
  controllers: [UnlockRequestsController],
  providers: [UnlockRequestsService],
})
export class UnlockRequestsModule {}
