import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiParam,
} from '@nestjs/swagger';
import { Request } from 'express';
import { AuthService } from './auth.service';
import { TelegramAuthDto } from './dto/telegram-auth.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { ChildPairDto } from './dto/child-pair.dto';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RedeemDeviceLinkDto } from './dto/device-link.dto';
import { Public } from '../../common/decorators';
import { ConsumerJwtAuthGuard } from '../../common/guards';
import { CurrentUser } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';

@ApiTags('Auth')
@Controller('auth')
@UseGuards(ConsumerJwtAuthGuard)
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('telegram')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Authenticate via Telegram Login Widget' })
  @ApiResponse({ status: 200, description: 'Tokens + user profile returned' })
  @ApiResponse({ status: 401, description: 'Invalid hash or expired auth data' })
  async telegramLogin(
    @Body() dto: TelegramAuthDto,
    @Req() req: Request,
  ) {
    return this.authService.telegramLogin(dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post('register')
  @Public()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Register a parent via email/phone + password' })
  @ApiResponse({ status: 201, description: 'Tokens + user profile returned' })
  @ApiResponse({ status: 400, description: 'Email/phone missing or invalid' })
  @ApiResponse({ status: 409, description: 'Email or phone already registered' })
  async register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.authService.register(dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post('login')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login a parent via email/phone + password' })
  @ApiResponse({ status: 200, description: 'Tokens + user profile returned' })
  @ApiResponse({ status: 401, description: 'Invalid credentials' })
  async login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.authService.login(dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post('refresh')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh access token using refresh token (rotation)' })
  @ApiResponse({ status: 200, description: 'New access + refresh tokens' })
  @ApiResponse({ status: 401, description: 'Invalid, expired or revoked token' })
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshToken(dto.refreshToken);
  }

  @Post('child-pair')
  @Public()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Pair child device using family code (anonymous endpoint)',
  })
  @ApiResponse({ status: 201, description: 'Child paired, tokens returned' })
  @ApiResponse({ status: 404, description: 'Family code not found' })
  @ApiResponse({
    status: 409,
    description: 'Child already paired, awaiting parent confirmation',
  })
  async childPair(@Body() dto: ChildPairDto, @Req() req: Request) {
    return this.authService.childPair(dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('child-pair-status/:id')
  @Public()
  @ApiOperation({ summary: 'Poll re-pair request status' })
  @ApiParam({ name: 'id', description: 'Pair request ID' })
  @ApiResponse({ status: 200, description: 'Current pair request status' })
  @ApiResponse({ status: 404, description: 'Pair request not found' })
  async childPairStatus(@Param('id') id: string) {
    return this.authService.childPairStatus(id);
  }

  @Post('logout')
  @ApiBearerAuth('consumer-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Logout — joriy qurilma sessiyasini tugatadi',
  })
  @ApiResponse({ status: 200, description: 'Logged out successfully' })
  async logout(@CurrentUser() user: JwtPayload) {
    return this.authService.logout(user.userId, user.sid);
  }

  /* ──────────────── Device-link (QR 2-qurilma) ──────────────── */

  @Post('device-link/create')
  @ApiBearerAuth('consumer-jwt')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: "QR uchun qisqa muddatli ulanish kodi yaratish (mas'ul qurilma)",
  })
  @ApiResponse({ status: 201, description: 'Kod + amal qilish muddati' })
  async createDeviceLink(@CurrentUser() user: JwtPayload) {
    return this.authService.createDeviceLink(user.userId);
  }

  @Post('device-link/redeem')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'QR kodni skanerlab ikkinchi qurilma sifatida kirish',
  })
  @ApiResponse({ status: 200, description: 'Tokens + user profile returned' })
  @ApiResponse({ status: 401, description: 'Kod yaroqsiz yoki muddati tugagan' })
  async redeemDeviceLink(
    @Body() dto: RedeemDeviceLinkDto,
    @Req() req: Request,
  ) {
    return this.authService.redeemDeviceLink(
      dto.code,
      { deviceModel: dto.deviceModel, platform: dto.platform },
      {
        ip: req.ip,
        headers: req.headers as Record<string, string | string[] | undefined>,
      },
    );
  }

  /* ──────────────── Faol sessiyalar ──────────────── */

  @Get('sessions')
  @ApiBearerAuth('consumer-jwt')
  @ApiOperation({ summary: 'Faol sessiyalar (login qilingan qurilmalar)' })
  @ApiResponse({ status: 200, description: 'Sessiyalar ro\'yxati' })
  async sessions(@CurrentUser() user: JwtPayload) {
    return this.authService.listSessions(user.userId, user.sid);
  }

  // DIQQAT: `others` `:id`'dan OLDIN — static route param'ga tushib qolmasin.
  @Delete('sessions/others')
  @ApiBearerAuth('consumer-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Joriydan boshqa barcha sessiyalarni tugatish' })
  @ApiResponse({ status: 200, description: 'Tugatilgan sessiyalar soni' })
  async revokeOtherSessions(@CurrentUser() user: JwtPayload) {
    return this.authService.revokeOtherSessions(user.userId, user.sid);
  }

  @Delete('sessions/:id')
  @ApiBearerAuth('consumer-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiParam({ name: 'id', description: 'Session ID' })
  @ApiOperation({ summary: 'Bitta sessiyani tugatish' })
  @ApiResponse({ status: 200, description: 'Sessiya tugatildi' })
  @ApiResponse({ status: 404, description: 'Sessiya topilmadi' })
  async revokeSession(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.authService.revokeSession(user.userId, id);
  }
}
