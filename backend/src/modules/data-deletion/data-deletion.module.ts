import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { DataDeletionController } from './data-deletion.controller';
import { DataDeletionNotifyService } from './data-deletion-notify.service';
import { DataDeletionService } from './data-deletion.service';

/** Bolaning ma'lumotlarini o'chirish so'rovi (Men I09). PrismaService va AuditService global. */
@Module({
  imports: [FcmModule],
  controllers: [DataDeletionController],
  providers: [DataDeletionService, DataDeletionNotifyService],
})
export class DataDeletionModule {}
