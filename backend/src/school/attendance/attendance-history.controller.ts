import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { AttendanceEarlyExitService } from './attendance-early-exit.service';
import { AttendanceReportsService } from './attendance-reports.service';

/** Maktab paneli: erta ketishlar, ota-onaga xabarlar jurnali, oylik hisobot va tarix. */
@ApiTags('School - Attendance history')
@SchoolAuth()
@Controller('school/attendance')
export class AttendanceHistoryController {
  constructor(
    private readonly earlyExits: AttendanceEarlyExitService,
    private readonly reports: AttendanceReportsService,
  ) {}

  @Get('early-exits')
  listEarlyExits(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.earlyExits.list(actor, query);
  }

  @Post('early-exits')
  createEarlyExit(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.earlyExits.create(actor, body);
  }

  /** Qaror: `{ approve: boolean }`. */
  @Post('early-exits/:id/decision')
  @HttpCode(HttpStatus.OK)
  decideEarlyExit(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.earlyExits.decide(actor, id, body);
  }

  @Get('notifications')
  notifications(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.reports.notifications(actor, query);
  }

  @Get('month-report')
  monthReport(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.reports.monthReport(actor, query);
  }

  @Get('trend')
  trend(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.reports.trend(actor, query);
  }

  @Get('students/:id/month')
  studentMonth(@Actor() actor: SchoolActor, @Param('id') id: string, @Query() query: unknown) {
    return this.reports.studentMonth(actor, id, query);
  }
}
