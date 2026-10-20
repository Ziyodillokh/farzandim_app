import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { GuardiansService } from './guardians.service';

@ApiTags('School - Guardians')
@SchoolAuth()
@Controller('school/guardians')
export class GuardiansController {
  constructor(private readonly guardians: GuardiansService) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.guardians.list(actor, query);
  }

  @Get('stats')
  stats(@Actor() actor: SchoolActor) {
    return this.guardians.stats(actor);
  }

  @Get('link-summary')
  @ApiOperation({ summary: 'Ota-onalar ulanishi: o\'quvchilar va ota-onalar ulushi' })
  linkSummary(@Actor() actor: SchoolActor) {
    return this.guardians.linkSummary(actor);
  }

  @Post('invite-bulk')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Filtrdagi taklif qilinmagan ota-onalarga taklif kodi' })
  inviteBulk(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.guardians.inviteBulk(actor, body);
  }

  @Post(':id/invite')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Taklif kodi (7 kun) — Parvoz Parents ilovasida kiritiladi' })
  invite(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.guardians.invite(actor, id);
  }

  @Put(':id')
  update(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.guardians.update(actor, id, body);
  }
}
