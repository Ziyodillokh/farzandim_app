import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  Query,
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
import {
  SendRegisterOtpDto,
  VerifyRegisterOtpDto,
} from './dto/register-otp.dto';
import {
  SendRegisterEmailOtpDto,
  VerifyRegisterEmailOtpDto,
} from './dto/register-email-otp.dto';
import { LoginDto } from './dto/login.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { RedeemDeviceLinkDto } from './dto/device-link.dto';
import { RedeemRepairTokenDto } from './dto/redeem-repair-token.dto';
import { RequestSessionAccessDto } from './dto/request-session-access.dto';
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

  @Post('google')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login/register via Google ID token' })
  @ApiResponse({ status: 200, description: 'Tokens + user profile returned' })
  @ApiResponse({ status: 401, description: 'Invalid Google ID token' })
  async googleLogin(@Body() dto: SocialLoginDto, @Req() req: Request) {
    return this.authService.googleLogin(dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post('apple')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login/register via Apple ID token' })
  @ApiResponse({ status: 200, description: 'Tokens + user profile returned' })
  @ApiResponse({ status: 401, description: 'Invalid Apple ID token' })
  async appleLogin(@Body() dto: SocialLoginDto, @Req() req: Request) {
    return this.authService.appleLogin(dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post('send-register-otp')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send SMS OTP (Eskiz) to verify phone before register' })
  @ApiResponse({ status: 200, description: 'OTP sent' })
  @ApiResponse({ status: 400, description: 'Recent code already sent / cooldown' })
  @ApiResponse({ status: 409, description: 'Phone already registered' })
  @ApiResponse({ status: 503, description: 'SMS service not configured' })
  async sendRegisterOtp(@Body() dto: SendRegisterOtpDto) {
    return this.authService.sendRegisterOtp(dto.phone);
  }

  @Post('verify-register-otp')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify the SMS OTP code sent before register' })
  @ApiResponse({ status: 200, description: 'Code verified' })
  @ApiResponse({ status: 400, description: 'Wrong/expired code or too many attempts' })
  async verifyRegisterOtp(@Body() dto: VerifyRegisterOtpDto) {
    return this.authService.verifyRegisterOtp(dto.phone, dto.code);
  }

  @Post('send-register-email-otp')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send email OTP (nodemailer) to verify email before register' })
  @ApiResponse({ status: 200, description: 'OTP sent' })
  @ApiResponse({ status: 400, description: 'Recent code already sent / cooldown' })
  @ApiResponse({ status: 409, description: 'Email already registered' })
  @ApiResponse({ status: 503, description: 'Email service not configured' })
  async sendRegisterEmailOtp(@Body() dto: SendRegisterEmailOtpDto) {
    return this.authService.sendRegisterEmailOtp(dto.email);
  }

  @Post('verify-register-email-otp')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify the email OTP code sent before register' })
  @ApiResponse({ status: 200, description: 'Code verified' })
  @ApiResponse({ status: 400, description: 'Wrong/expired code or too many attempts' })
  async verifyRegisterEmailOtp(@Body() dto: VerifyRegisterEmailOtpDto) {
    return this.authService.verifyRegisterEmailOtp(dto.email, dto.code);
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

  /* ──────────────── Child Re-pair (QR yangi qurilma) ──────────────── */

  @Post('child/:childId/repair-qr')
  @ApiBearerAuth('consumer-jwt')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: "Bola uchun qayta ulash QR kodi yaratish (45s amal qiladi)",
  })
  @ApiParam({ name: 'childId', description: 'Bola ID' })
  @ApiResponse({ status: 201, description: '{ token, expiresInSec }' })
  @ApiResponse({ status: 401, description: 'Faqat shu bolaning ota-onasi' })
  @ApiResponse({ status: 404, description: 'Bola topilmadi' })
  async createChildRepairQr(
    @Param('childId') childId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.authService.createChildRepairToken(user.userId, childId);
  }

  @Post('repair-redeem')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      "QR token bilan bolaga qayta ulanish (anonim — QR'ni bilish kifoya)",
  })
  @ApiResponse({
    status: 200,
    description: '{ accessToken, refreshToken, user, child }',
  })
  @ApiResponse({
    status: 401,
    description: 'Token yaroqsiz yoki muddati tugagan',
  })
  async redeemRepairToken(
    @Body() dto: RedeemRepairTokenDto,
    @Req() req: Request,
  ) {
    return this.authService.redeemChildRepairToken(
      dto.token,
      { deviceModel: dto.deviceModel, platform: dto.platform },
      {
        ip: req.ip,
        headers: req.headers as Record<string, string | string[] | undefined>,
      },
    );
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

  /* ──────────────── Session access (2-qurilma limit) ──────────────── */

  @Post('session-access/request')
  @Public()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: "Ruxsat so'rash — 2 ta ulangan qurilmaga push, poll ma'lumoti",
  })
  @ApiResponse({
    status: 201,
    description: '{ requestId, pollToken, pollIntervalSec }',
  })
  @ApiResponse({ status: 401, description: 'pendingToken yaroqsiz/muddati tugagan' })
  async requestSessionAccess(
    @Body() dto: RequestSessionAccessDto,
    @Req() req: Request,
  ) {
    return this.authService.requestSessionAccess(dto, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('session-access/status/:id')
  @Public()
  @ApiOperation({ summary: "Kirish so'rovi holatini poll qilish" })
  @ApiParam({ name: 'id', description: 'Session access request ID' })
  @ApiResponse({
    status: 200,
    description: "Holat (APPROVED bo'lib slot bo'shsa — tokenlar)",
  })
  @ApiResponse({ status: 404, description: "So'rov topilmadi" })
  async sessionAccessStatus(
    @Param('id') id: string,
    @Query('token') token: string,
    @Req() req: Request,
  ) {
    return this.authService.sessionAccessStatus(id, token, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Get('session-access/pending')
  @ApiBearerAuth('consumer-jwt')
  @ApiOperation({ summary: "Ochiq kirish so'rovlari (tasdiqlash uchun)" })
  @ApiResponse({ status: 200, description: "PENDING so'rovlar ro'yxati" })
  async sessionAccessPending(@CurrentUser() user: JwtPayload) {
    return this.authService.listPendingSessionAccess(user.userId);
  }

  @Post('session-access/:id/approve')
  @ApiBearerAuth('consumer-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiParam({ name: 'id', description: 'Session access request ID' })
  @ApiOperation({ summary: "Kirish so'rovini tasdiqlash" })
  async approveSessionAccess(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.authService.approveSessionAccess(user.userId, id);
  }

  @Post('session-access/:id/reject')
  @ApiBearerAuth('consumer-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiParam({ name: 'id', description: 'Session access request ID' })
  @ApiOperation({ summary: "Kirish so'rovini rad etish" })
  async rejectSessionAccess(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.authService.rejectSessionAccess(user.userId, id);
  }
}
