import { Module } from '@nestjs/common';
import { StorageModule } from '../../common/storage/storage.module';
import { DatabaseModule } from '../../common/database/database.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { FcmModule } from '../../common/fcm/fcm.module';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { TelegramSupportService } from './telegram-support.service';

@Module({
  imports: [StorageModule, DatabaseModule, RealtimeModule, FcmModule],
  controllers: [SupportController],
  providers: [SupportService, TelegramSupportService],
})
export class SupportModule {}
