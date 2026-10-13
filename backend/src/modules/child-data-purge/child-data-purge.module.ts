import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { ChildDataPurgeService } from './child-data-purge.service';

/**
 * Bola ma'lumotlarini o'chirish (bola o'zi yoki ota-ona) — UsersModule va
 * ChildrenModule ikkalasi ishlatadi, shuning uchun alohida modul (aylanma
 * importsiz).
 */
@Module({
  imports: [FcmModule, RealtimeModule],
  providers: [ChildDataPurgeService],
  exports: [ChildDataPurgeService],
})
export class ChildDataPurgeModule {}
