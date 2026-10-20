import { Body, Controller, Get, HttpCode, HttpStatus, Post, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { AttendanceKioskService } from './attendance-kiosk.service';

/** Kirish nuqtasi (kiosk) — `attendance.kiosk` ruxsati (navbatchi, admin). */
@ApiTags('School - Attendance kiosk')
@SchoolAuth()
@Controller('school/attendance/kiosk')
export class AttendanceKioskController {
  constructor(private readonly kiosk: AttendanceKioskService) {}

  /** Aylanuvchi QR tokeni: `{ token, issuedAt, expiresAt, rotatesInSeconds }`. */
  @Get('token')
  token(@Actor() actor: SchoolActor) {
    return this.kiosk.token(actor);
  }

  @Post('check-in')
  @HttpCode(HttpStatus.OK)
  checkIn(@Actor() actor: SchoolActor, @Body() body: unknown) {
    return this.kiosk.checkIn(actor, body);
  }

  @Get('search')
  search(@Actor() actor: SchoolActor, @Query() query: unknown) {
    return this.kiosk.kioskSearch(actor, query);
  }

  @Get('stats')
  stats(@Actor() actor: SchoolActor) {
    return this.kiosk.kioskStats(actor);
  }
}
