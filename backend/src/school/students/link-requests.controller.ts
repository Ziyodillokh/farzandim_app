import { Controller, Get, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { LinkRequestsService } from './link-requests.service';

/** Ulanish so'rovlari: tasdiq kutayotgan bog'lanishlar (UNDER_REVIEW) va bolaning tuzatish so'rovlari. */
@ApiTags('School - Link requests')
@SchoolAuth()
@Controller('school/link-requests')
export class LinkRequestsController {
  constructor(private readonly requests: LinkRequestsService) {}

  @Get()
  @ApiOperation({ summary: "Tasdiq kutayotgan bog'lanishlar va ochiq tuzatish so'rovlari (doira bo'yicha)" })
  list(@Actor() actor: SchoolActor) {
    return this.requests.list(actor);
  }

  @Post(':id/confirm')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Bog'lanishni tasdiqlash / tuzatish so'rovida bog'lanishni saqlab qolish" })
  confirm(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.requests.confirm(actor, id);
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "O'quvchi o'rnini bo'shatish / tuzatish so'rovida bog'lanishni uzish" })
  reject(@Actor() actor: SchoolActor, @Param('id') id: string) {
    return this.requests.reject(actor, id);
  }
}
