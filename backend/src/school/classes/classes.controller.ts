import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { ClassesService } from './classes.service';

@ApiTags('School - Classes')
@SchoolAuth()
@Controller('school/classes')
export class ClassesController {
  constructor(private readonly classes: ClassesService) {}

  @Get()
  list(
    @Actor() actor: SchoolActor,
    @Query('shiftId') shiftId?: string,
    @Query('search') search?: string,
  ) {
    return this.classes.list(actor, { shiftId, search });
  }

  @Get(':id')
  get(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.classes.get(actor, id);
  }

  @Get(':id/detail')
  detail(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.classes.detail(actor, id);
  }

  @Post()
  create(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.classes.create(actor, body);
  }

  @Put(':id')
  update(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.classes.update(actor, id, body);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Actor() actor: SchoolActor, @Param('id') id: string) {
    await this.classes.remove(actor, id);
  }
}
