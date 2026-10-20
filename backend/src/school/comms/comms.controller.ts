import { Body, Controller, Get, HttpCode, HttpStatus, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { CommsOverviewService } from './comms-overview.service';

/** Xabarlar umumiy (panel `commsService.audienceSize / templates / overview`). */
@ApiTags('School - Comms')
@SchoolAuth()
@Controller('school/comms')
export class CommsController {
  constructor(private readonly overviewService: CommsOverviewService) {}

  /** Auditoriya hajmi — tanlov (massivlar) tanada, shuning uchun POST. */
  @Post('audience-size')
  @HttpCode(HttpStatus.OK)
  audienceSize(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.overviewService.audienceSize(actor, body);
  }

  @Get('templates')
  templates(@Actor() actor: SchoolActor) {
    return this.overviewService.templates(actor);
  }

  @Get('overview')
  overview(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.overviewService.overview(actor, query);
  }
}
