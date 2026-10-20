// Parvoz School — School Mode (`/api/school/school-mode`): siyosat, smenalar,
// istisnolar, favqulodda o'chirish, qurilmalar va bola qurilmasiga virtual
// "Maktab" jadvallari (`SchoolModeSyncService` — RoutinesModule ishlatadi).

import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { SchoolCoreModule } from '../school-core.module';
import { SchoolModeControlService } from './school-mode-control.service';
import { SchoolModeMorningCron } from './school-mode-morning.cron';
import { SchoolModePolicyService } from './school-mode-policy.service';
import { SchoolModeReadsService } from './school-mode-reads.service';
import { SchoolModeStore } from './school-mode-store';
import { SchoolModeSyncService } from './school-mode-sync.service';
import { SchoolModeController } from './school-mode.controller';

@Module({
  imports: [SchoolCoreModule, FcmModule],
  controllers: [SchoolModeController],
  providers: [SchoolModeStore, SchoolModeSyncService, SchoolModeReadsService, SchoolModePolicyService, SchoolModeControlService, SchoolModeMorningCron],
  exports: [SchoolModeSyncService, SchoolModeReadsService],
})
export class SchoolModeModule {}
