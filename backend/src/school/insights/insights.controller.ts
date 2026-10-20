import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { DashboardService } from './dashboard.service';
import { NotificationsService } from './notifications.service';
import { ReportsService } from './reports.service';
import { SearchService } from './search.service';

/** Bosh sahifa, bildirishnomalar markazi, oylik hisobot va global qidiruv. */
@ApiTags('School - Insights')
@SchoolAuth()
@Controller('school')
export class InsightsController {
  constructor(
    private readonly dashboard: DashboardService,
    private readonly notifications: NotificationsService,
    private readonly reports: ReportsService,
    private readonly search: SearchService,
  ) {}

  @Get('dashboard/overview')
  @ApiOperation({ summary: 'Rolga mos bosh sahifa (ruxsatsiz bo\'lim — null)' })
  overview(@Actor() actor: SchoolActor) {
    return this.dashboard.overview(actor);
  }

  @Get('notifications/feed')
  feed(@Actor() actor: SchoolActor) {
    return this.notifications.feed(actor);
  }

  @Get('reports/monthly')
  monthly(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.reports.monthly(actor, query);
  }

  @Get('search')
  query(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.search.query(actor, query);
  }
}
