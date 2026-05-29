import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { AdminAnalyticsService } from './admin-analytics.service';
import { AdminJwtAuthGuard, PermissionsGuard } from '../../common/guards';
import { Permissions } from '../../common/decorators';

@ApiTags('Admin - Analytics')
@ApiBearerAuth('admin-jwt')
@Controller('admin/analytics')
@UseGuards(AdminJwtAuthGuard, PermissionsGuard)
@Permissions('view_analytics')
export class AdminAnalyticsController {
  constructor(private readonly service: AdminAnalyticsService) {}

  @Get()
  @ApiOperation({ summary: 'General analytics overview snapshot' })
  async getOverview() {
    return this.service.getOverview();
  }

  @Get('monetization')
  @ApiOperation({ summary: 'Monetization analytics (revenue, plans, growth)' })
  async getMonetization() {
    return this.service.getMonetization();
  }

  @Get('videos')
  @ApiOperation({ summary: 'Video stats (VideoMessage placeholder)' })
  async getVideoStats() {
    return this.service.getVideoStats();
  }

  @Get('user-growth')
  @ApiOperation({ summary: 'User growth statistics' })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  @ApiQuery({ name: 'months', required: false, type: Number })
  async getUserGrowth(
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('months') months?: string,
  ) {
    return this.service.getUserGrowth({
      from,
      to,
      months: months ? +months : undefined,
    });
  }

  @Get('engagement')
  @ApiOperation({ summary: 'User engagement / retention stats' })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  async getEngagement(
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.service.getEngagement({ from, to });
  }

  @Get('content-stats')
  @ApiOperation({ summary: 'Content statistics (videos, audiobooks, books, olympiads)' })
  async getContentStats() {
    return this.service.getContentStats();
  }
}
