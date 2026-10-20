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
import { SchoolInfoService } from './school-info.service';

@ApiTags('School - Info')
@Controller('school')
export class SchoolInfoController {
  constructor(private readonly info: SchoolInfoService) {}

  /** Kirish sahifasi brendi (sessiyasiz). */
  @Get('public/brand')
  brand(@Query('code') code = '') {
    return this.info.brand(code);
  }

  @Get('info')
  @SchoolAuth()
  get(@Actor() actor: SchoolActor) {
    return this.info.get(actor);
  }

  @Put('info')
  @SchoolAuth()
  update(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.info.updateProfile(actor, body);
  }

  @Put('logo')
  @SchoolAuth()
  setLogo(@Actor() actor: SchoolActor, @Body() body: { logo?: unknown } | undefined) {
    return this.info.setLogo(actor, body?.logo ?? null);
  }

  @Post('holidays')
  @SchoolAuth()
  addHoliday(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.info.addHoliday(actor, body);
  }

  @Delete('holidays/:id')
  @SchoolAuth()
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeHoliday(@Actor() actor: SchoolActor, @Param('id') id: string) {
    await this.info.removeHoliday(actor, id);
  }
}
