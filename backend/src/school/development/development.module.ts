// Parvoz School — rivojlanish (`/api/school/development`): psixologik test
// natijalaridan o'quvchi profili, sinf va maktab kesimi, e'tibor ro'yxati.
// Ko'rinish serverda: psixolog — to'liq; sinf rahbari — o'z sinfi (xom ballsiz);
// direktor / admin — faqat K=5 agregatlar va faqat yakuniy natijalardan.

import { Module } from '@nestjs/common';
import { AssessmentsModule } from '../assessments/assessments.module';
import { SchoolCoreModule } from '../school-core.module';
import { DevelopmentContextService } from './development-context.service';
import { DevelopmentDataService } from './development-data.service';
import { DevelopmentSummaryService } from './development-summary.service';
import { DevelopmentController } from './development.controller';
import { DevelopmentService } from './development.service';

@Module({
  imports: [SchoolCoreModule, AssessmentsModule],
  controllers: [DevelopmentController],
  providers: [DevelopmentDataService, DevelopmentContextService, DevelopmentService, DevelopmentSummaryService],
  exports: [DevelopmentSummaryService],
})
export class DevelopmentModule {}
