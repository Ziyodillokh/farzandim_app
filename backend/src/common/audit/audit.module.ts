import { Global, Module } from '@nestjs/common';
import { AuditService } from './audit.service';
import { AdminAuditService } from './admin-audit.service';

@Global()
@Module({
  providers: [AuditService, AdminAuditService],
  exports: [AuditService, AdminAuditService],
})
export class AuditModule {}
