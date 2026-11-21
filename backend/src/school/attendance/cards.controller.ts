import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { CardReservationsService } from './card-reservations.service';
import { CardsService } from './cards.service';

/** NFC kartalar (panel «Kartalar»): ro'yxat, biriktirish, bloklash, tegishlar jurnali. */
@ApiTags('School - Cards')
@SchoolAuth()
@Controller('school/cards')
export class CardsController {
  constructor(
    private readonly cards: CardsService,
    private readonly reservations: CardReservationsService,
  ) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.cards.list(actor, query);
  }

  @Get('taps')
  taps(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.cards.taps(actor, query);
  }

  /** Karta partiyasi: raqam ajratilgan, chip hali bog'lanmagan o'quvchilar (bosmaxona ro'yxati). */
  @Get('reservations')
  listReservations(@Actor() actor: SchoolActor) {
    return this.reservations.list(actor);
  }

  @Post('reservations')
  @HttpCode(HttpStatus.OK)
  reserve(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.reservations.reserve(actor, body);
  }

  @Delete('reservations/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async cancelReservation(@Actor() actor: SchoolActor, @Param('id') id: string) {
    await this.reservations.cancel(actor, id);
  }

  @Post('reservations/:id/bind')
  bindReservation(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.reservations.bind(actor, id, body);
  }

  /** Ta'minotchi fayli: kartaga bosilgan raqam ↔ chip UID, bir yo'la. */
  @Post('import')
  @HttpCode(HttpStatus.OK)
  importBindings(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.reservations.importBindings(actor, body);
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
