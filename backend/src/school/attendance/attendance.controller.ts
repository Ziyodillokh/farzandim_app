import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { AttendanceBoardService } from './attendance-board.service';
import { AttendanceMarkingService } from './attendance-marking.service';

/** Maktab paneli: davomat taxtasi, sinf kuni, jonli oqim, belgilash va tuzatishlar. */
@ApiTags('School - Attendance')
@SchoolAuth()
@Controller('school/attendance')
export class AttendanceController {
  constructor(
    private readonly board: AttendanceBoardService,
    private readonly marking: AttendanceMarkingService,
  ) {}

  @Get('board')
  getBoard(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.board.board(actor, query);
  }

  @Get('class-options')
  classOptions(@Actor() actor: SchoolActor) {
    return this.board.classOptions(actor);
  }

  /** Sinf kartochkasi (`classes.today`) — bugungi kun. */
  @Get('classes/:id/today')
  classToday(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.board.classDay(actor, id, {});
  }

  @Get('classes/:id')
  classDay(@Actor() actor: SchoolActor, @Param('id') id: string, @Query() query: unknown) {
    return this.board.classDay(actor, id, query);
  }

  @Get('feed')
  feed(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.board.feed(actor, query);
  }

  @Post('mark')
  @HttpCode(HttpStatus.OK)
  mark(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.marking.mark(actor, body);
  }

  @Post('corrections')
  @HttpCode(HttpStatus.OK)
  correct(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.marking.correct(actor, body);
  }

  @Get('corrections')
  corrections(@Actor() actor: SchoolActor) {
    return this.marking.corrections(actor);
  }
}
