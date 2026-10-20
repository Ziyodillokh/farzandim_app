// Parvoz School — maktab paneli backend'i (`/api/school/*`).

import { Module } from '@nestjs/common';
import { AttendanceModule } from './attendance/attendance.module';
import { CareModule } from './care/care.module';
import { AuditController } from './audit/audit.controller';
import { AuditService } from './audit/audit.service';
import { SchoolAuthController } from './auth/school-auth.controller';
import { SchoolAuthService } from './auth/school-auth.service';
import { ClassesController } from './classes/classes.controller';
import { ClassesService } from './classes/classes.service';
import { CommsModule } from './comms/comms.module';
import { InsightsModule } from './insights/insights.module';
import { SchoolLearningModule } from './learning/school-learning.module';
import { ProfileController } from './profile/profile.controller';
import { ProfileService } from './profile/profile.service';
import { SchoolCoreModule } from './school-core.module';
import { SchoolModeModule } from './school-mode/school-mode.module';
import { StaffController } from './staff/staff.controller';
import { StaffService } from './staff/staff.service';
import { StudentsModule } from './students/students.module';
import { SchoolInfoController } from './structure/school-info.controller';
import { SchoolInfoService } from './structure/school-info.service';

@Module({
  imports: [SchoolCoreModule, StudentsModule, AttendanceModule, CommsModule, SchoolModeModule, CareModule, InsightsModule, SchoolLearningModule],
  controllers: [
    SchoolAuthController,
    SchoolInfoController,
    ClassesController,
    StaffController,
    AuditController,
    ProfileController,
  ],
  providers: [SchoolAuthService, SchoolInfoService, ClassesService, StaffService, AuditService, ProfileService],
})
export class SchoolModule {}
