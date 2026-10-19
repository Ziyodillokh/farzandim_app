import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SchoolStaffRole } from '@prisma/client';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { StaffService } from './staff.service';

@ApiTags('School - Staff')
@SchoolAuth()
@Controller('school/staff')
export class StaffController {
  constructor(private readonly staff: StaffService) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.staff.list(actor, query);
  }

  @Get('options')
  options(@Actor() actor: SchoolActor, @Query('role') role?: SchoolStaffRole) {
    return this.staff.options(actor, role);
  }

  @Get('summary')
  summary(@Actor() actor: SchoolActor) {
    return this.staff.summary(actor);
  }

  @Get('roles')
  roles(@Actor() actor: SchoolActor) {
    return this.staff.roles(actor);
  }

  @Post()
  create(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.staff.create(actor, body);
  }

  @Put(':id')
  update(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.staff.update(actor, id, body);
  }

  @Patch(':id/active')
  setActive(
    @Actor() actor: SchoolActor,
    @Param('id') id: string,
    @Body() body: { active?: unknown } | undefined,
  ) {
    return this.staff.setActive(actor, id, body?.active);
  }

  @Put(':id/account')
  setAccount(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.staff.setAccount(actor, id, body);
  }

  @Delete(':id/account')
  removeAccount(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.staff.removeAccount(actor, id);
  }
}
