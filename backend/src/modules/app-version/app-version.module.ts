import { Module } from '@nestjs/common';
import { AppVersionController } from './app-version.controller';
import { AppVersionService } from './app-version.service';
import { StoreVersionSyncService } from './store-version-sync.service';

@Module({
  controllers: [AppVersionController],
  providers: [AppVersionService, StoreVersionSyncService],
  exports: [AppVersionService],
})
export class AppVersionModule {}
