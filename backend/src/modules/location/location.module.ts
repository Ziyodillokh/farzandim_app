import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { BatteryAlertModule } from '../../common/battery/battery-alert.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { LocationController } from './location.controller';
import { LocationService } from './location.service';

@Module({
  imports: [FcmModule, BatteryAlertModule, RealtimeModule],
  controllers: [LocationController],
  providers: [LocationService],
  exports: [LocationService],
})
export class LocationModule {}
