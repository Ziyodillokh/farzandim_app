import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { StorageModule } from '../../common/storage/storage.module';
import { AuditModule } from '../../common/audit/audit.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { PhotoRequestsController } from './photo-requests.controller';
import { PhotoRequestsService } from './photo-requests.service';

@Module({
  imports: [DatabaseModule, StorageModule, AuditModule, RealtimeModule],
  controllers: [PhotoRequestsController],
  providers: [PhotoRequestsService],
  exports: [PhotoRequestsService],
})
export class PhotoRequestsModule {}
