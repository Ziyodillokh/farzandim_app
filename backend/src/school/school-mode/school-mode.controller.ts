import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Put, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { SchoolModeControlService } from './school-mode-control.service';
import { SchoolModePolicyService } from './school-mode-policy.service';
import { SchoolModeReadsService } from './school-mode-reads.service';

@ApiTags('School - School Mode')
@SchoolAuth()
@Controller('school/school-mode')
export class SchoolModeController {
  constructor(
    private readonly reads: SchoolModeReadsService,
    private readonly policies: SchoolModePolicyService,
    private readonly control: SchoolModeControlService,
  ) {}

  @Get('overview')
  @ApiOperation({ summary: 'Jonli holat: sinflar, qurilmalar, smenalar, favqulodda holat' })
  overview(@Actor() actor: SchoolActor) {
    return this.reads.overview(actor);
  }

  @Get('devices')
  devices(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.reads.devices(actor, query);
  }

  @Post('remind')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Ruxsati yo\'q qurilmalar ota-onalariga push-eslatma' })
  remind(@Actor() actor: SchoolActor, @Body() body: { studentIds?: unknown } | undefined) {
    return this.policies.remindParents(actor, body?.studentIds);
  }

  @Get('policy')
  policy(@Actor() actor: SchoolActor) {
    return this.reads.policy(actor);
  }

  @Put('policy')
  updatePolicy(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.policies.updatePolicy(actor, body);
  }

  @Post('policy/apps')
  addAllowedApp(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.policies.addAllowedApp(actor, body);
  }

  @Delete('policy/apps/:appId')
  removeAllowedApp(@Actor() actor: SchoolActor, @Param('appId') appId: string) {
    return this.policies.removeAllowedApp(actor, appId);
  }

  @Get('shifts')
  shifts(@Actor() actor: SchoolActor) {
    return this.reads.shifts(actor);
  }

  @Put('shifts/:id')
  updateShift(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.policies.updateShift(actor, id, body);
  }

  @Get('exceptions')
  exceptions(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.reads.exceptions(actor, query);
  }

  @Post('exceptions')
  createException(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.control.createException(actor, body);
  }

  @Post('exceptions/:id/revoke')
  @HttpCode(HttpStatus.OK)
  revokeException(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.control.revokeException(actor, id);
  }

  @Post('emergency')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Favqulodda o\'chirish (butun maktab yoki sinflar)' })
  activateEmergency(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.control.activateEmergency(actor, body);
  }

  @Post('emergency/off')
  @HttpCode(HttpStatus.OK)
  deactivateEmergency(@Actor() actor: SchoolActor) {
    return this.control.deactivateEmergency(actor);
  }

  @Get('classes/now')
  classesNow(@Actor() actor: SchoolActor) {
    return this.reads.classesNow(actor);
  }

  @Get('classes/:id/now')
  classNow(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.reads.classNow(actor, id);
  }
}
