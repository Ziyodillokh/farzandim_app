// Parvoz School — o'quvchilar, ota-onalar va Parvoz Parents bilan bog'lanish
// (`/api/school/students`, `/api/school/guardians`, `/api/parent/school`), o'quvchi kodi va bola ilovasi
// bog'lanishi (`/api/child/school/link*`, `/api/school/link-requests`).

import { Module } from '@nestjs/common';
import { SchoolCoreModule } from '../school-core.module';
import { ChildLinkController } from './child-link.controller';
import { ChildLinkService } from './child-link.service';
import { GuardiansController } from './guardians.controller';
import { GuardiansService } from './guardians.service';
import { LinkAttemptLimiter } from './link-attempt-limiter';
import { LinkRequestsController } from './link-requests.controller';
import { LinkRequestsService } from './link-requests.service';
import { ParentLinksService } from './parent-links.service';
import { ParentSchoolController } from './parent-school.controller';
import { Student360Service } from './student-360.service';
import { StudentInvitesService } from './student-invites.service';
import { StudentsWriteService } from './students-write.service';
import { StudentsController } from './students.controller';
import { StudentsService } from './students.service';

@Module({
  imports: [SchoolCoreModule],
  controllers: [StudentsController, GuardiansController, ParentSchoolController, ChildLinkController, LinkRequestsController],
  providers: [
    StudentsService,
    StudentsWriteService,
    Student360Service,
    GuardiansService,
    ParentLinksService,
    StudentInvitesService,
    ChildLinkService,
    LinkRequestsService,
    LinkAttemptLimiter,
  ],
  exports: [StudentsService, GuardiansService],
})
export class StudentsModule {}
