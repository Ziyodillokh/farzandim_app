import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { RemindersService } from './reminders.service';

/** Smart Reminder (panel `commsService.reminders`). */
@ApiTags('School - Comms')
@SchoolAuth()
@Controller('school/comms/reminders')
export class CommsRemindersController {
  constructor(private readonly reminders: RemindersService) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.reminders.list(actor, query);
  }

  @Post()
  create(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.reminders.create(actor, body);
  }

  @Put(':id')
  update(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.reminders.update(actor, id, body);
  }

  @Patch(':id/active')
  setActive(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.reminders.setActive(actor, id, body);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Actor() actor: SchoolActor, @Param('id') id: string) {
    await this.reminders.remove(actor, id);
  }
}
