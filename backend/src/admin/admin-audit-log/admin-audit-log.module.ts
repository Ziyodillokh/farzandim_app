import { Module } from '@nestjs/common';
import { AdminAuditLogController } from './admin-audit-log.controller';
import { AdminAuditLogService } from './admin-audit-log.service';

@Module({
  controllers: [AdminAuditLogController],
  providers: [AdminAuditLogService],
})
export class AdminAuditLogModule {}
