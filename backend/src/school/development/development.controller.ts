import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { DevelopmentService } from './development.service';

/** Rivojlanish: o'quvchi profili, sinf va maktab kesimi, e'tibor ro'yxati. */
@ApiTags('School - Development')
@SchoolAuth()
@Controller('school/development')
export class DevelopmentController {
  constructor(private readonly development: DevelopmentService) {}

  @Get('students/:id/profile')
  @ApiOperation({ summary: 'O\'quvchi profili (psixolog — to\'liq; sinf rahbari — o\'z sinfi, xom ballsiz)' })
  studentProfile(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.development.studentProfile(actor, id);
  }

  @Get('classes/:id/overview')
  classOverview(@Actor() actor: SchoolActor, @Param('id') id: string, @Query() query: Record<string, unknown>) {
    return this.development.classOverview(actor, id, query);
  }

  @Get('school/overview')
  @ApiOperation({ summary: 'Maktab kesimi (direktor / admin — K=5 va faqat yakuniy natijalar)' })
  schoolOverview(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.development.schoolOverview(actor, query);
  }

  @Get('attention')
  @ApiOperation({ summary: 'E\'tibor ro\'yxati (faqat psixolog)' })
  attentionList(@Actor() actor: SchoolActor) {
    return this.development.attentionList(actor);
  }

  @Get('class-options')
  classOptions(@Actor() actor: SchoolActor) {
    return this.development.classOptions(actor);
  }

  @Get('term-options')
  termOptions(@Actor() actor: SchoolActor) {
    return this.development.termOptions(actor);
  }
}
