// Parvoz School — psixologik testlar (`/api/school/assessments`,
// `/api/child/school/assessments`): shablonlar (kodda) va maktab testlari,
// konstruktor + versiyalar, JSON / CSV import, tayinlash, bola ilovasida yechish
// (javoblar shifrlangan), natijalar — rolga qarab (psixolog / sinf rahbari).

import { Module } from '@nestjs/common';
import { IqModule } from '../../modules/iq/iq.module';
import { SchoolCoreModule } from '../school-core.module';
import { AssessmentsAssignService } from './assessments-assign.service';
import { AssessmentsChildController } from './assessments-child.controller';
import { AssessmentsChildService } from './assessments-child.service';
import { AssessmentsCsvService } from './assessments-csv.service';
import { AssessmentsEditorService } from './assessments-editor.service';
import { AssessmentsIqService } from './assessments-iq.service';
import { AssessmentsLibraryService } from './assessments-library.service';
import { AssessmentsResultsService } from './assessments-results.service';
import { AssessmentsStatusService } from './assessments-status.service';
import { AssessmentsStore } from './assessments-store';
import { AssessmentsController } from './assessments.controller';

@Module({
  imports: [SchoolCoreModule, IqModule],
  controllers: [AssessmentsController, AssessmentsChildController],
  providers: [
    AssessmentsStore,
    AssessmentsLibraryService,
    AssessmentsEditorService,
    AssessmentsStatusService,
    AssessmentsAssignService,
    AssessmentsResultsService,
    AssessmentsCsvService,
    AssessmentsChildService,
    AssessmentsIqService,
  ],
  exports: [AssessmentsStore],
})
export class AssessmentsModule {}
