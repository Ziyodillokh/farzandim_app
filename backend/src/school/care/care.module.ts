// Parvoz School — Bola ovozi (`/api/school/care`, `/api/child/school/care`):
// so'rovnomalar, savollar banki, anonim natija (K=5), psixologga murojaatlar.
// Bolaning javoblari va matnlari bazada shifrlangan (SchoolCryptoService).

import { Module } from '@nestjs/common';
import { SchoolCoreModule } from '../school-core.module';
import { CareChildController } from './care-child.controller';
import { CareChildService } from './care-child.service';
import { CareInsightsService } from './care-insights.service';
import { CareRequestsService } from './care-requests.service';
import { CareStore } from './care-store';
import { CareSurveysService } from './care-surveys.service';
import { CareController } from './care.controller';

@Module({
  imports: [SchoolCoreModule],
  controllers: [CareController, CareChildController],
  providers: [CareStore, CareSurveysService, CareInsightsService, CareRequestsService, CareChildService],
  exports: [CareStore, CareInsightsService],
})
export class CareModule {}
