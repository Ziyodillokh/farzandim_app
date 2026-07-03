import {
  Controller,
  Get,
  Put,
  Post,
  Delete,
  Body,
  Req,
  HttpCode,
  HttpStatus,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiConsumes,
  ApiBody,
} from '@nestjs/swagger';
import { Request } from 'express';
import { FastifyRequest } from 'fastify';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyPhoneDto } from './dto/verify-phone.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { RequestEmailOtpDto } from './dto/request-email-otp.dto';
import { VerifyEmailDto } from './dto/verify-email.dto';
import { CurrentUser } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';

/** @fastify/multipart yuklagan fayl (req.file()). */
interface MultipartFile {
  toBuffer(): Promise<Buffer>;
  mimetype: string;
  filename: string;
}
interface MultipartRequest {
  file(): Promise<MultipartFile | undefined>;
}

@ApiTags('Users')
@ApiBearerAuth('consumer-jwt')
@Controller('users')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current user profile' })
  @ApiResponse({ status: 200, description: 'User profile' })
  @ApiResponse({ status: 404, description: 'User not found' })
  async getProfile(@CurrentUser() user: JwtPayload) {
    return this.usersService.getProfile(user.userId);
  }

  @Put('me')
  @ApiOperation({ summary: 'Update current user profile' })
  @ApiResponse({ status: 200, description: 'Updated user data' })
  async updateProfile(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateUserDto,
  ) {
    return this.usersService.updateProfile(user.userId, dto);
  }

  @Delete('me')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Delete account and all associated data (Play Store requirement)',
  })
  @ApiResponse({ status: 200, description: 'Account deleted' })
  @ApiResponse({ status: 404, description: 'User not found' })
  async deleteAccount(
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    return this.usersService.deleteAccount(user.userId, {
      ip: req.ip,
      headers: req.headers as Record<string, string | string[] | undefined>,
    });
  }

  @Post('me/avatar')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  @ApiOperation({ summary: 'Upload profile avatar (max 5 MB, JPEG/PNG/WebP)' })
  @ApiResponse({ status: 200, description: 'Avatar uploaded, signed URL returned' })
  @ApiResponse({ status: 413, description: 'File too large' })
  @ApiResponse({ status: 415, description: 'Unsupported image format' })
  async uploadAvatar(
    @CurrentUser() user: JwtPayload,
    @Req() req: FastifyRequest,
  ) {
    // Fastify adapter — @fastify/multipart req.file() (main.ts'da ro'yxatda).
    const data = await (req as unknown as MultipartRequest).file();
    if (!data) {
      throw new BadRequestException('Fayl yuborilmadi');
    }
    const buffer = await data.toBuffer();
    return this.usersService.uploadAvatar(user.userId, {
      buffer,
      mimetype: data.mimetype,
      originalname: data.filename,
    });
  }

  @Post('me/phone')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request OTP code for phone verification' })
  @ApiResponse({ status: 200, description: 'OTP sent' })
  @ApiResponse({ status: 409, description: 'Phone already in use' })
  @ApiResponse({ status: 400, description: 'Cooldown — try again later' })
  @ApiResponse({ status: 502, description: 'SMS delivery failed' })
  @ApiResponse({ status: 503, description: 'SMS provider not configured' })
  async requestPhoneOtp(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RequestOtpDto,
  ) {
    return this.usersService.requestPhoneOtp(user.userId, dto);
  }

  @Post('me/phone/verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify phone with OTP code' })
  @ApiResponse({ status: 200, description: 'Phone verified and saved' })
  @ApiResponse({
    status: 400,
    description: 'Invalid/expired code or too many attempts',
  })
  @ApiResponse({ status: 409, description: 'Phone already in use' })
  async verifyPhoneOtp(
    @CurrentUser() user: JwtPayload,
    @Body() dto: VerifyPhoneDto,
  ) {
    return this.usersService.verifyPhoneOtp(user.userId, dto);
  }

  @Post('me/password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Change password with old password' })
  @ApiResponse({ status: 200, description: 'Password changed' })
  @ApiResponse({ status: 400, description: 'Wrong old password / no password' })
  async changePassword(
    @CurrentUser() user: JwtPayload,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.usersService.changePassword(user.userId, dto);
  }

  @Post('me/password/request-otp')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request password-reset OTP to current phone' })
  @ApiResponse({ status: 200, description: 'OTP sent' })
  @ApiResponse({ status: 400, description: 'No phone / cooldown' })
  @ApiResponse({ status: 502, description: 'SMS delivery failed' })
  @ApiResponse({ status: 503, description: 'SMS provider not configured' })
  async requestPasswordOtp(@CurrentUser() user: JwtPayload) {
    return this.usersService.requestPasswordOtp(user.userId);
  }

  @Post('me/password/reset')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reset password with OTP code' })
  @ApiResponse({ status: 200, description: 'Password reset' })
  @ApiResponse({ status: 400, description: 'Invalid or expired code' })
  async resetPassword(
    @CurrentUser() user: JwtPayload,
    @Body() dto: ResetPasswordDto,
  ) {
    return this.usersService.resetPasswordWithOtp(user.userId, dto);
  }

  @Post('me/email')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request OTP code for new email verification' })
  @ApiResponse({ status: 200, description: 'OTP sent to new email' })
  @ApiResponse({ status: 409, description: 'Email already in use' })
  @ApiResponse({ status: 400, description: 'Cooldown — try again later' })
  @ApiResponse({ status: 502, description: 'Email delivery failed' })
  @ApiResponse({ status: 503, description: 'Mail provider not configured' })
  async requestEmailOtp(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RequestEmailOtpDto,
  ) {
    return this.usersService.requestEmailOtp(user.userId, dto);
  }

  @Post('me/email/verify')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify email with OTP code' })
  @ApiResponse({ status: 200, description: 'Email verified and saved' })
  @ApiResponse({ status: 400, description: 'Invalid or expired code' })
  @ApiResponse({ status: 409, description: 'Email already in use' })
  async verifyEmailOtp(
    @CurrentUser() user: JwtPayload,
    @Body() dto: VerifyEmailDto,
  ) {
    return this.usersService.verifyEmailOtp(user.userId, dto);
  }
}
