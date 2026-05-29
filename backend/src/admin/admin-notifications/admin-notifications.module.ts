import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { StorageModule } from '../../common/storage/storage.module';
import { AdminNotificationsController } from './admin-notifications.controller';
import { AdminNotificationsService } from './admin-notifications.service';

@Module({
  imports: [FcmModule, StorageModule],
  controllers: [AdminNotificationsController],
  providers: [AdminNotificationsService],
})
export class AdminNotificationsModule {}
