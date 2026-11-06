import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser, Roles } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { BadgesService } from './badges/badges.service';
import { GamificationService } from './gamification.service';
import { DonLedgerService } from './ledger/don-ledger.service';
import { CreateXpEventDto } from './dto/create-xp-event.dto';
import { ListXpEventsDto } from './dto/list-xp-events.dto';
import { DevelopmentSummaryQueryDto } from './dto/development-summary-query.dto';
import { DonLedgerQueryDto } from './dto/don-ledger-query.dto';
import { Request } from 'express';

@ApiTags('Gamification')
@ApiBearerAuth()
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Controller()
export class GamificationController {
  constructor(
    private readonly service: GamificationService,
    private readonly ledger: DonLedgerService,
    private readonly badges: BadgesService,
  ) {}

  @Get('children/:childId/profile')
  @ApiOperation({ summary: 'Get child gamification profile' })
  getProfile(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.service.getProfile(childId, user.userId);
  }

  @Post('children/:childId/xp-events')
  // Faqat OTA-ONA qo'lda XP/don bera oladi. Avval rol cheklovi yo'q edi —
  // bola o'z JWT'si bilan cheksiz XP (reyting) va don (valyuta) yasay olardi.
  // Tizim mukofotlari (kontent tugatish, olympiad) alohida server-side
  // `awardXp` orqali beriladi, bu endpoint orqali emas.
  @Roles('PARENT')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create XP event (parent only)' })
  createXpEvent(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateXpEventDto,
    @Req() req: Request,
  ) {
    return this.service.createXpEvent(childId, user.userId, dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('children/:childId/xp-events')
  @ApiOperation({ summary: 'List XP events for a child' })
  listXpEvents(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: ListXpEventsDto,
  ) {
    return this.service.listXpEvents(childId, user.userId, query);
  }

  @Get('children/:childId/development-summary')
  @ApiOperation({ summary: 'Holistic weekly development index (#63)' })
  developmentSummary(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: DevelopmentSummaryQueryDto,
  ) {
    return this.service.getDevelopmentSummary(
      childId,
      user.userId,
      query.range ?? 'weekly',
    );
  }

  @Get('children/:childId/don-ledger')
  @ApiOperation({ summary: 'DON daftari: balans + yozuvlar (kursor bilan, yangisi birinchi)' })
  donLedger(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: DonLedgerQueryDto,
  ) {
    return this.ledger.list(childId, user.userId, query);
  }

  @Get('children/:childId/badges')
  @ApiOperation({ summary: 'Yutuqlar (badge) katalogi: ochilgan / ochilmagan' })
  listBadges(@Param('childId') childId: string, @CurrentUser() user: JwtPayload) {
    return this.badges.list(childId, user.userId);
  }
}
