import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { StaffThreadsService } from './staff-threads.service';

/** Maktab paneli: ota-onalar xodimning o'ziga yozgan xabarlari. */
@ApiTags('School - Parent threads')
@SchoolAuth()
@Controller('school/parent-threads')
export class StaffParentThreadsController {
  constructor(private readonly threads: StaffThreadsService) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.threads.list(actor, query);
  }

  @Get('summary')
  summary(@Actor() actor: SchoolActor) {
    return this.threads.summary(actor);
  }

  @Get(':id')
  get(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.threads.get(actor, id);
  }

  @Post(':id/messages')
  reply(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.threads.reply(actor, id, body);
  }

  @Post(':id/read')
  @HttpCode(HttpStatus.OK)
  read(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.threads.markRead(actor, id);
  }

  @Post(':id/status')
  @HttpCode(HttpStatus.OK)
  status(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.threads.setStatus(actor, id, body);
  }
}
