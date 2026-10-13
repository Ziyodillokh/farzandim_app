import { Module } from '@nestjs/common';
import { StorageModule } from '../../common/storage/storage.module';
import { FcmModule } from '../../common/fcm/fcm.module';
import { BatteryAlertModule } from '../../common/battery/battery-alert.module';
import { PermissionAlertModule } from '../../common/permission-alert/permission-alert.module';
import { ChildrenController } from './children.controller';
import { ChildrenService } from './children.service';
import { ChildDataPurgeModule } from '../child-data-purge/child-data-purge.module';

@Module({
  imports: [
    StorageModule,
    FcmModule,
    BatteryAlertModule,
    PermissionAlertModule,
    ChildDataPurgeModule,
  ],
  controllers: [ChildrenController],
  providers: [ChildrenService],
  exports: [ChildrenService],
})
export class ChildrenModule {}
