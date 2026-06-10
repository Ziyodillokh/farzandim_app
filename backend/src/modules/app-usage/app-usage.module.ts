import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { AuditModule } from '../../common/audit/audit.module';
import { FcmModule } from '../../common/fcm/fcm.module';
import { AppUsageController } from './app-usage.controller';
import { AppUsageService } from './app-usage.service';

@Module({
  imports: [DatabaseModule, AuditModule, FcmModule],
  controllers: [AppUsageController],
  providers: [AppUsageService],
  exports: [AppUsageService],
})
export class AppUsageModule {}
