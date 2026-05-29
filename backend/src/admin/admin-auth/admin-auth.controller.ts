import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import type { Request, Response } from 'express';
import { AdminAuthService } from './admin-auth.service';
import { LoginDto } from './dto/login.dto';
import { Verify2faDto } from './dto/verify-2fa.dto';
import { Enable2faDto } from './dto/enable-2fa.dto';
import { Disable2faDto } from './dto/disable-2fa.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { AdminJwtAuthGuard } from '../../common/guards';
import { CurrentStaff } from '../../common/decorators';
import { AdminJwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { Public } from '../../common/decorators';

// H7 — refresh token HttpOnly cookie. Browser XSS cannot read it.
const REFRESH_COOKIE = 'admin_refresh';
const REFRESH_COOKIE_PATH = '/api/admin/auth';
const REFRESH_COOKIE_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

/** Origin header — always present in browser POSTs, absent in native clients. */
function isBrowser(req: Request): boolean {
  return Boolean(req.headers.origin);
}

function setRefreshCookie(res: Response, token: string): void {
  res.cookie(REFRESH_COOKIE, token, {
    httpOnly: true,
    secure: true,
    sameSite: 'none',
    path: REFRESH_COOKIE_PATH,
    maxAge: REFRESH_COOKIE_MAX_AGE_MS,
  });
}

function clearRefreshCookie(res: Response): void {
  res.clearCookie(REFRESH_COOKIE, { path: REFRESH_COOKIE_PATH });
}

@ApiTags('Admin - Auth')
@Controller('admin/auth')
export class AdminAuthController {
  constructor(private readonly authService: AdminAuthService) {}

  @Post('login')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Admin login with email + password' })
  async login(
    @Body() dto: LoginDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.authService.login(dto, {
      ip: req.ip,
      headers: req.headers,
    });
    // 2FA branch — challenge response, no cookie yet
    if ((result as { requires2fa?: boolean }).requires2fa) {
      return result;
    }
    // H7 — browser: HttpOnly cookie for refresh token; native: body
    const tokens = result as {
      access_token: string;
      accessToken: string;
      refresh_token: string;
      refreshToken: string;
      user: unknown;
    };
    if (isBrowser(req)) {
      setRefreshCookie(res, tokens.refresh_token);
      return {
        access_token: tokens.access_token,
        accessToken: tokens.accessToken,
        user: tokens.user,
      };
    }
    return tokens;
  }

  @Post('2fa/verify')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify 2FA challenge with TOTP or backup code' })
  async verify2fa(
    @Body() dto: Verify2faDto,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.authService.verify2fa(dto, {
      ip: req.ip,
      headers: req.headers,
    });
    if (isBrowser(req)) {
      setRefreshCookie(res, result.refresh_token);
      return {
        access_token: result.access_token,
        accessToken: result.accessToken,
        user: result.user,
        usedBackupCode: result.usedBackupCode,
        remainingBackupCodes: result.remainingBackupCodes,
      };
    }
    return result;
  }

  @Get('2fa/status')
  @UseGuards(AdminJwtAuthGuard)
  @ApiBearerAuth('admin-jwt')
  @ApiOperation({ summary: 'Get current 2FA status' })
  async get2faStatus(@CurrentStaff() staff: AdminJwtPayload) {
    return this.authService.get2faStatus(staff.sub);
  }

  @Post('2fa/setup')
  @UseGuards(AdminJwtAuthGuard)
  @ApiBearerAuth('admin-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Generate new TOTP secret for 2FA setup' })
  async setup2fa(@CurrentStaff() staff: AdminJwtPayload) {
    return this.authService.setup2fa(staff.sub);
  }

  @Post('2fa/enable')
  @UseGuards(AdminJwtAuthGuard)
  @ApiBearerAuth('admin-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Enable 2FA after verifying TOTP code' })
  async enable2fa(
    @CurrentStaff() staff: AdminJwtPayload,
    @Body() dto: Enable2faDto,
    @Req() req: any,
  ) {
    return this.authService.enable2fa(staff.sub, dto, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  @Post('2fa/disable')
  @UseGuards(AdminJwtAuthGuard)
  @ApiBearerAuth('admin-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Disable 2FA with password + TOTP verification' })
  async disable2fa(
    @CurrentStaff() staff: AdminJwtPayload,
    @Body() dto: Disable2faDto,
    @Req() req: any,
  ) {
    return this.authService.disable2fa(staff.sub, dto, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  @Post('refresh')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh access token' })
  async refresh(@Body() dto: RefreshTokenDto, @Req() req: any) {
    const cookieToken = req.cookies?.admin_refresh;
    return this.authService.refresh(
      dto.refreshToken ?? dto.refresh_token,
      cookieToken,
    );
  }

  @Get('staff-me')
  @UseGuards(AdminJwtAuthGuard)
  @ApiBearerAuth('admin-jwt')
  @ApiOperation({ summary: 'Get current staff profile' })
  async staffMe(@CurrentStaff() staff: AdminJwtPayload) {
    return this.authService.getProfile(staff.sub);
  }

  @Post('change-password')
  @UseGuards(AdminJwtAuthGuard)
  @ApiBearerAuth('admin-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Change own password' })
  async changePassword(
    @CurrentStaff() staff: AdminJwtPayload,
    @Body() dto: ChangePasswordDto,
    @Req() req: any,
  ) {
    return this.authService.changePassword(staff.sub, dto, {
      ip: req.ip,
      headers: req.headers,
    });
  }

  @Post('logout')
  @UseGuards(AdminJwtAuthGuard)
  @ApiBearerAuth('admin-jwt')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Logout — revokes all refresh tokens' })
  async logout(
    @CurrentStaff() staff: AdminJwtPayload,
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.authService.logout(staff.sub, {
      ip: req.ip,
      headers: req.headers,
    });
    // H7 — clear refresh cookie on logout
    clearRefreshCookie(res);
    return result;
  }
}
