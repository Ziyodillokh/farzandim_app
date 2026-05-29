import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { AdminDashboardService } from './admin-dashboard.service';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { Permissions } from '../../common/decorators';

@ApiTags('Admin - Dashboard')
@ApiBearerAuth('admin-jwt')
@Controller('admin/dashboard')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('view_analytics')
export class AdminDashboardController {
  constructor(private readonly service: AdminDashboardService) {}

  @Get('stats')
  @ApiOperation({ summary: 'Dashboard summary stats with charts' })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  async getStats(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getStats(from, to);
  }

  /**
   * Port of Fastify `GET /api/admin/dashboard` root route. Returns the same
   * KPI snapshot as `/stats` so legacy clients hitting the bare module URL
   * keep working.
   */
  @Get()
  @ApiOperation({ summary: 'Dashboard root (alias for stats)' })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  async getRoot(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.getStats(from, to);
  }
}
