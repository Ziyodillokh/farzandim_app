import { Body, Controller, Get, Param, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { TimetableChildService } from './timetable-child.service';
import { TimetableService } from './timetable.service';

/** Sinf dars jadvali (panel). */
@ApiTags('School - Timetable')
@SchoolAuth()
@Controller('school/timetable')
export class TimetableController {
  constructor(private readonly timetable: TimetableService) {}

  @Get('classes/:classId')
  @ApiOperation({ summary: 'Sinf dars jadvali + smena davrlari' })
  get(@Actor() actor: SchoolActor, @Param('classId') classId: string) {
    return this.timetable.get(actor, classId);
  }

  @Put('classes/:classId')
  @ApiOperation({ summary: "Sinfning butun haftalik jadvalini almashtirish (atomik)" })
  replace(@Actor() actor: SchoolActor, @Param('classId') classId: string, @Body() body: unknown) {
    return this.timetable.replace(actor, classId, body);
  }
}

/** Parvoz Growth bola ilovasi: kunlik dars jadvali. */
@ApiTags('School (child app)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('child/school/timetable')
export class TimetableChildController {
  constructor(private readonly timetable: TimetableChildService) {}

  @Get()
  @ApiOperation({ summary: 'Sinfimning kunlik dars jadvali (?date=YYYY-MM-DD, bo\'sh — bugun)' })
  day(@CurrentUser() user: JwtPayload, @Query() query: Record<string, unknown>) {
    return this.timetable.day(user.userId, query);
  }
}
