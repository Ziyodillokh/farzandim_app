// Maktab modullari umumiy poydevori: token xizmati, guard, audit.
// Har bir maktab moduli shuni import qiladi (`@SchoolAuth()` ishlashi uchun).

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../common/database/database.module';
import { SchoolAuthGuard } from './auth/school-auth.guard';
import { SchoolTokensService } from './auth/school-tokens.service';
import { SchoolAuditService } from './common/school-audit.service';

@Module({
  imports: [DatabaseModule],
  providers: [SchoolTokensService, SchoolAuthGuard, SchoolAuditService],
  exports: [DatabaseModule, SchoolTokensService, SchoolAuthGuard, SchoolAuditService],
})
export class SchoolCoreModule {}
