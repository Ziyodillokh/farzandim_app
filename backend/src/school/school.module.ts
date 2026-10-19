// Parvoz School — maktab paneli backend'i (`/api/school/*`).

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../common/database/database.module';
import { SchoolAuthController } from './auth/school-auth.controller';
import { SchoolAuthGuard } from './auth/school-auth.guard';
import { SchoolAuthService } from './auth/school-auth.service';
import { SchoolTokensService } from './auth/school-tokens.service';
import { SchoolAuditService } from './common/school-audit.service';
import { AuditController } from './audit/audit.controller';
import { AuditService } from './audit/audit.service';
import { ClassesController } from './classes/classes.controller';
import { ClassesService } from './classes/classes.service';
import { ProfileController } from './profile/profile.controller';
import { ProfileService } from './profile/profile.service';
import { StaffController } from './staff/staff.controller';
import { StaffService } from './staff/staff.service';
import { SchoolInfoController } from './structure/school-info.controller';
import { SchoolInfoService } from './structure/school-info.service';

@Module({
  imports: [DatabaseModule],
  controllers: [
    SchoolAuthController,
    SchoolInfoController,
    ClassesController,
    StaffController,
    AuditController,
    ProfileController,
  ],
  providers: [
    SchoolAuthService,
    SchoolTokensService,
    SchoolAuthGuard,
    SchoolAuditService,
    SchoolInfoService,
    ClassesService,
    StaffService,
    AuditService,
    ProfileService,
  ],
  exports: [SchoolTokensService, SchoolAuthGuard, SchoolAuditService],
})
export class SchoolModule {}
