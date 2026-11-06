import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { FastifyRequest } from 'fastify';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { SCHOOL_LINK_LIMIT } from '../../common/throttle/throttle.config';
import { UserThrottlerGuard } from '../../common/throttle/user-throttler.guard';
import { ChildLinkService } from './child-link.service';

/** Parvoz Growth bola ilovasi: maktab o'quvchi kodi (6 raqam), bog'lanish holati va tuzatish so'rovi (K2). */
@ApiTags('School (child app) - link')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('child/school')
export class ChildLinkController {
  constructor(private readonly link: ChildLinkService) {}

  // Umumiy so'rov chegarasi BOLA bo'yicha (IP bo'yicha emas: maktab Wi-Fi'sidagi boshqa bolalar zarar ko'rmasin);
  // tanlab topishga qarshi asosiy himoya — xato urinishlar limiti (`LinkAttemptLimiter`).
  @Post('link')
  @UseGuards(UserThrottlerGuard)
  @Throttle({ schoolLink: SCHOOL_LINK_LIMIT })
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "O'quvchi kodini kiritish (6 raqam): UNDER_REVIEW yoki (ota-ona tasdiqlasa) CONFIRMED" })
  redeem(@CurrentUser() user: JwtPayload, @Body() body: unknown, @Req() req: FastifyRequest) {
    return this.link.redeem(user.userId, body, req.ip);
  }

  @Get('link-status')
  @ApiOperation({ summary: "Bog'lanish holati; maktab / sinf nomi faqat CONFIRMED'da" })
  status(@CurrentUser() user: JwtPayload) {
    return this.link.status(user.userId);
  }

  @Post('correction')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: "Maktab yoki sinf noto'g'ri (A08): ochiq bo'lganda maktab ma'lumoti yopiq; clientRequestId — idempotent" })
  correction(@CurrentUser() user: JwtPayload, @Body() body: unknown) {
    return this.link.requestCorrection(user.userId, body);
  }
}
