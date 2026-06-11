import { Module } from '@nestjs/common';
import { FcmModule } from '../fcm/fcm.module';
import { BatteryAlertService } from './battery-alert.service';

@Module({
  imports: [FcmModule],
  providers: [BatteryAlertService],
  exports: [BatteryAlertService],
})
export class BatteryAlertModule {}
