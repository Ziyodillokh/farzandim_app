import { Module } from '@nestjs/common';
import { FcmModule } from '../fcm/fcm.module';
import { PermissionAlertService } from './permission-alert.service';

/**
 * PermissionAlertModule — ruxsat granted→denied ogohlantirishi (#43).
 * PrismaService global (DatabaseModule), FcmService FcmModule'dan.
 */
@Module({
  imports: [FcmModule],
  providers: [PermissionAlertService],
  exports: [PermissionAlertService],
})
export class PermissionAlertModule {}
