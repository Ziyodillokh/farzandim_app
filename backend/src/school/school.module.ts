// Parvoz School — maktab paneli backend'i (`/api/school/*`).

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../common/database/database.module';
import { SchoolAuthController } from './auth/school-auth.controller';
import { SchoolAuthGuard } from './auth/school-auth.guard';
import { SchoolAuthService } from './auth/school-auth.service';
import { SchoolTokensService } from './auth/school-tokens.service';
import { SchoolAuditService } from './common/school-audit.service';
import { SchoolInfoController } from './structure/school-info.controller';
import { SchoolInfoService } from './structure/school-info.service';

@Module({
  imports: [DatabaseModule],
  controllers: [SchoolAuthController, SchoolInfoController],
  providers: [
    SchoolAuthService,
    SchoolTokensService,
    SchoolAuthGuard,
    SchoolAuditService,
    SchoolInfoService,
  ],
  exports: [SchoolTokensService, SchoolAuthGuard, SchoolAuditService],
})
export class SchoolModule {}
