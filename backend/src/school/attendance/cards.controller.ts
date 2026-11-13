import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { CardsService } from './cards.service';

/** NFC kartalar (panel «Kartalar»): ro'yxat, biriktirish, bloklash, tegishlar jurnali. */
@ApiTags('School - Cards')
@SchoolAuth()
@Controller('school/cards')
export class CardsController {
  constructor(private readonly cards: CardsService) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.cards.list(actor, query);
  }

  @Get('taps')
  taps(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.cards.taps(actor, query);
  }

  @Post()
  assign(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.cards.assign(actor, body);
  }

  @Post(':id/block')
  @HttpCode(HttpStatus.OK)
  block(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.cards.block(actor, id, body);
  }

  @Post(':id/unblock')
  @HttpCode(HttpStatus.OK)
  unblock(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.cards.unblock(actor, id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Actor() actor: SchoolActor, @Param('id') id: string) {
    await this.cards.remove(actor, id);
  }
}
