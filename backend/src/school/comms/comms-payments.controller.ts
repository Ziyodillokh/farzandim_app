import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { PaymentUpdatesService } from './payment-updates.service';
import { PaymentsService } from './payments.service';
import { VerificationsService } from './verifications.service';

/** To'lov eslatmalari (panel `commsService.payments`). */
@ApiTags('School - Comms')
@SchoolAuth()
@Controller('school/comms/payments')
export class CommsPaymentsController {
  constructor(
    private readonly payments: PaymentsService,
    private readonly updates: PaymentUpdatesService,
  ) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.payments.list(actor, query);
  }

  @Get('stats')
  stats(@Actor() actor: SchoolActor) {
    return this.payments.stats(actor);
  }

  /** CSV eksport — filtr bo'yicha barcha qatorlar. */
  @Get('export')
  exportRows(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.payments.exportRows(actor, query);
  }

  /** Oila uchun yangi eslatma (panelda hozircha UI yo'q). */
  @Post()
  create(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.payments.create(actor, body);
  }

  @Post('bulk-shift')
  @HttpCode(HttpStatus.OK)
  bulkShift(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.updates.bulkShift(actor, body);
  }

  @Post(':id/shift')
  @HttpCode(HttpStatus.OK)
  shift(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.updates.shift(actor, id, body);
  }

  @Post(':id/pause')
  @HttpCode(HttpStatus.OK)
  pause(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.updates.pause(actor, id, body);
  }

  @Post(':id/resume')
  @HttpCode(HttpStatus.OK)
  resume(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.updates.resume(actor, id, body);
  }

  @Get(':id/history')
  history(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.payments.history(actor, id);
  }
}

/** Tekshiruv so'rovlari (panel `commsService.verifications`). */
@ApiTags('School - Comms')
@SchoolAuth()
@Controller('school/comms/verifications')
export class CommsVerificationsController {
  constructor(private readonly verifications: VerificationsService) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.verifications.list(actor, query);
  }

  @Post(':id/answer')
  @HttpCode(HttpStatus.OK)
  answer(@Actor() actor: SchoolActor, @Param('id') id: string, @Body() body: unknown) {
    return this.verifications.answer(actor, id, body);
  }

  @Post(':id/close')
  @HttpCode(HttpStatus.OK)
  close(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.verifications.close(actor, id);
  }
}
