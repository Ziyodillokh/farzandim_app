// Parvoz School — o'quvchilar, ota-onalar va Parvoz Parents bilan bog'lanish
// (`/api/school/students`, `/api/school/guardians`, `/api/parent/school`).

import { Module } from '@nestjs/common';
import { SchoolCoreModule } from '../school-core.module';
import { GuardiansController } from './guardians.controller';
import { GuardiansService } from './guardians.service';
import { ParentLinksService } from './parent-links.service';
import { ParentSchoolController } from './parent-school.controller';
import { Student360Service } from './student-360.service';
import { StudentsWriteService } from './students-write.service';
import { StudentsController } from './students.controller';
import { StudentsService } from './students.service';

@Module({
  imports: [SchoolCoreModule],
  controllers: [StudentsController, GuardiansController, ParentSchoolController],
  providers: [StudentsService, StudentsWriteService, Student360Service, GuardiansService, ParentLinksService],
  exports: [StudentsService, GuardiansService],
})
export class StudentsModule {}
