import { Module } from '@nestjs/common';
import { StorageModule } from '../../common/storage/storage.module';
import { FcmModule } from '../../common/fcm/fcm.module';
import { BatteryAlertModule } from '../../common/battery/battery-alert.module';
import { ChildrenController } from './children.controller';
import { ChildrenService } from './children.service';

@Module({
  imports: [StorageModule, FcmModule, BatteryAlertModule],
  controllers: [ChildrenController],
  providers: [ChildrenService],
  exports: [ChildrenService],
})
export class ChildrenModule {}
