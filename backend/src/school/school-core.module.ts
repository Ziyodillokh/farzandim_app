// Maktab modullari umumiy poydevori: token xizmati, guard, audit, shifrlash.
// Har bir maktab moduli shuni import qiladi (`@SchoolAuth()` ishlashi uchun).

import { Module } from '@nestjs/common';
import { DatabaseModule } from '../common/database/database.module';
import { SchoolAuthGuard } from './auth/school-auth.guard';
import { SchoolTokensService } from './auth/school-tokens.service';
import { SchoolAuditService } from './common/school-audit.service';
import { SchoolCryptoService } from './common/school-crypto.service';

@Module({
  imports: [DatabaseModule],
  providers: [SchoolTokensService, SchoolAuthGuard, SchoolAuditService, SchoolCryptoService],
  exports: [DatabaseModule, SchoolTokensService, SchoolAuthGuard, SchoolAuditService, SchoolCryptoService],
})
export class SchoolCoreModule {}
