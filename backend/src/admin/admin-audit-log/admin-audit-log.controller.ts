import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { AdminAuditLogService } from './admin-audit-log.service';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { Permissions } from '../../common/decorators';

@ApiTags('Admin - Audit Log')
@ApiBearerAuth('admin-jwt')
@Controller('admin/audit-log')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('view_audit_log', 'view_analytics')
export class AdminAuditLogController {
  constructor(private readonly service: AdminAuditLogService) {}

  @Get()
  @ApiOperation({ summary: 'List audit log entries (paginated, filterable)' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'moderatorId', required: false })
  @ApiQuery({ name: 'action', required: false })
  @ApiQuery({ name: 'resourceType', required: false })
  @ApiQuery({ name: 'resourceId', required: false })
  @ApiQuery({ name: 'status', required: false })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  async list(
    @Query('page') page = 1,
    @Query('limit') limit = 50,
    @Query('moderatorId') moderatorId?: string,
    @Query('action') action?: string,
    @Query('resourceType') resourceType?: string,
    @Query('resourceId') resourceId?: string,
    @Query('status') status?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.service.list({
      page: Math.max(1, +page || 1),
      limit: Math.min(100, Math.max(1, +limit || 50)),
      moderatorId,
      action,
      resourceType,
      resourceId,
      status,
      from,
      to,
    });
  }

  @Get('actions')
  @ApiOperation({ summary: 'List distinct audit action types (for filter dropdown)' })
  async getActions() {
    return this.service.getActions();
  }
}
