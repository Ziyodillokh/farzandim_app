import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { StorageModule } from '../../common/storage/storage.module';
import { AuditModule } from '../../common/audit/audit.module';
import { SchoolModeModule } from '../../school/school-mode/school-mode.module';
import { InstalledAppsController } from './installed-apps.controller';
import { InstalledAppsService } from './installed-apps.service';

@Module({
  imports: [DatabaseModule, StorageModule, AuditModule, SchoolModeModule],
  controllers: [InstalledAppsController],
  providers: [InstalledAppsService],
  exports: [InstalledAppsService],
})
export class InstalledAppsModule {}
