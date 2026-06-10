import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { AuditModule } from '../../common/audit/audit.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { FcmModule } from '../../common/fcm/fcm.module';
import { AppLimitsController } from './app-limits.controller';
import { AppLimitsService } from './app-limits.service';

@Module({
  imports: [DatabaseModule, AuditModule, RealtimeModule, FcmModule],
  controllers: [AppLimitsController],
  providers: [AppLimitsService],
  exports: [AppLimitsService],
})
export class AppLimitsModule {}
