import { Body, Controller, Get, Header, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, Public, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { StructuredThrottlerGuard } from '../../common/throttle/structured-throttler.guard';
import { CHILD_LOGIN_IP_LIMIT, THROTTLER_NAMES } from '../../common/throttle/throttle.config';
import {
  ChildLoginService,
  ChildOkBody,
  ChildSetupRequiredBody,
} from './child-login.service';
import { ChildSessionsService, DeviceView } from './child-sessions.service';
import { ChangeChildPasswordDto, ChildLoginDto, ChildSetupDto } from './dto/child-login.dto';

/** Bola kirishi: login/parol, birinchi kirishda parol o'rnatish, parol almashtirish, qurilmalar. */
@ApiTags('Child auth')
@Controller('auth')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
export class ChildLoginController {
  constructor(
    private readonly login: ChildLoginService,
    private readonly sessions: ChildSessionsService,
  ) {}

  @Post('child-login')
  @Public()
  @UseGuards(StructuredThrottlerGuard)
  @Throttle({ [THROTTLER_NAMES.childLogin]: CHILD_LOGIN_IP_LIMIT })
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Bola login + parol bilan kiradi (yoki parol o\'rnatish talab etiladi)' })
  @ApiResponse({ status: 200, description: '{ status: OK, tokens… } yoki { status: SETUP_REQUIRED, setupToken }' })
  @ApiResponse({ status: 401, description: 'INVALID_CREDENTIALS (noto\'g\'ri login yoki parol — bir xil)' })
  @ApiResponse({ status: 429, description: 'LOCKED (15 daqiqada 5 xato) yoki RATE_LIMITED (IP)' })
  childLogin(@Body() dto: ChildLoginDto): Promise<ChildOkBody | ChildSetupRequiredBody> {
    return this.login.login(dto);
  }

  @Post('child-setup')
  @Public()
  @UseGuards(StructuredThrottlerGuard)
  @Throttle({ [THROTTLER_NAMES.childLogin]: CHILD_LOGIN_IP_LIMIT })
  @HttpCode(HttpStatus.OK)
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Birinchi kirish: setupToken bilan o\'z parolini o\'rnatadi va kiradi' })
  @ApiResponse({ status: 401, description: 'SETUP_TOKEN_INVALID (muddati tugagan / ishlatilgan / yaroqsiz)' })
  @ApiResponse({ status: 400, description: 'WEAK_PASSWORD' })
  childSetup(@Body() dto: ChildSetupDto): Promise<ChildOkBody> {
    return this.login.setup(dto);
  }

  @Post('child/password')
  @Roles('CHILD')
  @ApiBearerAuth('consumer-jwt')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Bola parolini almashtiradi; boshqa LOGIN sessiyalar yopiladi' })
  @ApiResponse({ status: 400, description: 'WRONG_PASSWORD | WEAK_PASSWORD' })
  @ApiResponse({ status: 404, description: 'NO_CREDENTIAL (oila kodi bilan juftlangan, login berilmagan)' })
  @ApiResponse({ status: 429, description: 'LOCKED' })
  async changePassword(@CurrentUser() user: JwtPayload, @Body() dto: ChangeChildPasswordDto): Promise<void> {
    await this.login.changePassword(user, dto);
  }

  @Get('child/devices')
  @Roles('CHILD')
  @ApiBearerAuth('consumer-jwt')
  @ApiOperation({ summary: 'Bola qurilmalari: LOGIN sessiyalari + juftlangan qurilma' })
  devices(@CurrentUser() user: JwtPayload): Promise<DeviceView[]> {
    return this.sessions.devices(user.userId, user.sid);
  }
}
