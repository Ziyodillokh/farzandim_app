import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { AuditModule } from '../../common/audit/audit.module';
import { AppUsageController } from './app-usage.controller';
import { AppUsageService } from './app-usage.service';

@Module({
  imports: [DatabaseModule, AuditModule],
  controllers: [AppUsageController],
  providers: [AppUsageService],
  exports: [AppUsageService],
})
export class AppUsageModule {}
