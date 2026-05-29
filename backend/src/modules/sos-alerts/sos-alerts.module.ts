import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { AuditModule } from '../../common/audit/audit.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { FcmModule } from '../../common/fcm/fcm.module';
import { SosAlertsController } from './sos-alerts.controller';
import { SosAlertsService } from './sos-alerts.service';

@Module({
  imports: [DatabaseModule, AuditModule, RealtimeModule, FcmModule],
  controllers: [SosAlertsController],
  providers: [SosAlertsService],
  exports: [SosAlertsService],
})
export class SosAlertsModule {}
