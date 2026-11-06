// Parvoz School — Bola ovozi (`/api/school/care`, `/api/child/school/care`):
// anonim so'rovnomalar, savollar banki, anonim natija (K=5), psixologga murojaat
// yozishmasi, mas'ul psixolog / ish vaqti sozlamalari va eskalatsiya cron'i.
// Bolaning javoblari va matnlari bazada shifrlangan (SchoolCryptoService).

import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { SchoolCoreModule } from '../school-core.module';
import { CareChildRequestsService } from './care-child-requests.service';
import { CareChildController } from './care-child.controller';
import { CareChildService } from './care-child.service';
import { CareEscalationCron } from './care-escalation.cron';
import { CareInsightsService } from './care-insights.service';
import { CareNotifyService } from './care-notify.service';
import { CareRequestRows } from './care-request-rows';
import { CareRequestsService } from './care-requests.service';
import { CareSettingsService } from './care-settings.service';
import { CareStore } from './care-store';
import { CareSurveysService } from './care-surveys.service';
import { CareController } from './care.controller';

@Module({
  imports: [SchoolCoreModule, FcmModule],
  controllers: [CareController, CareChildController],
  providers: [
    CareStore,
    CareSurveysService,
    CareInsightsService,
    CareRequestRows,
    CareRequestsService,
    CareSettingsService,
    CareNotifyService,
    CareChildService,
    CareChildRequestsService,
    CareEscalationCron,
  ],
  exports: [CareStore, CareInsightsService, CareSettingsService],
})
export class CareModule {}
