import { Body, Controller, Get, Header, HttpCode, HttpStatus, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../../common/decorators';
import { ConsumerJwtAuthGuard } from '../../common/guards';
import { StructuredThrottlerGuard } from '../../common/throttle/structured-throttler.guard';
import {
  CHILD_RECOVERY_IP_LIMIT,
  CHILD_RECOVERY_LOGIN_LIMIT,
  THROTTLER_NAMES,
} from '../../common/throttle/throttle.config';
import { ChildRecoveryService, RecoveryStatusView } from './child-recovery.service';
import { ChildRecoveryRequestDto } from './dto/child-recovery.dto';

/** Kirish maʼlumotlarini tiklash (bola, autentifikatsiyasiz). Mavjudlik hech qachon ochilmaydi. */
@ApiTags('Child auth')
@Controller('auth')
@UseGuards(ConsumerJwtAuthGuard)
export class ChildRecoveryController {
  constructor(private readonly recovery: ChildRecoveryService) {}

  @Post('child-recovery')
  @Public()
  @UseGuards(StructuredThrottlerGuard)
  @Throttle({
    [THROTTLER_NAMES.childRecoveryLogin]: CHILD_RECOVERY_LOGIN_LIMIT,
    [THROTTLER_NAMES.childRecoveryIp]: CHILD_RECOVERY_IP_LIMIT,
  })
  @HttpCode(HttpStatus.ACCEPTED)
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Kirish maʼlumotlarini tiklashni so\'raydi (DOIM 202, login mavjudligi ochilmaydi)' })
  @ApiResponse({ status: 202, description: '{ requestId, pollToken }' })
  @ApiResponse({ status: 429, description: 'RATE_LIMITED (login: 3/sutka, IP: 10/sutka)' })
  request(@Body() dto: ChildRecoveryRequestDto): Promise<{ requestId: string; pollToken: string }> {
    return this.recovery.request(dto);
  }

  @Get('child-recovery/:requestId')
  @Public()
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'So\'rov holatini poll qiladi (pollToken bilan)' })
  @ApiResponse({ status: 404, description: 'So\'rov yoki token noto\'g\'ri (bir xil javob)' })
  status(@Param('requestId') requestId: string, @Query('token') token: string): Promise<RecoveryStatusView> {
    return this.recovery.status(requestId, token);
  }
}
