// Parvoz ilovalari (consumer JWT): Growth — QR kirish va bugungi holat;
// Parents — erta ketish so'rovi va farzandning oylik davomati.

import { Body, Controller, Get, HttpCode, HttpStatus, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { AttendanceChildService } from './attendance-child.service';
import { AttendanceParentService } from './attendance-parent.service';

@ApiTags('School attendance (child)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('CHILD')
@Controller('child/school')
export class AttendanceChildController {
  constructor(private readonly child: AttendanceChildService) {}

  @Post('check-in')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Kiosk QR tokeni bilan kirish (smena tugagach — chiqish)' })
  checkIn(@CurrentUser() user: JwtPayload, @Body() body: unknown) {
    return this.child.checkIn(user.userId, body);
  }

  @Get('today')
  @ApiOperation({ summary: 'Bugungi davomat holati; maktabga bog\'lanmagan bo\'lsa null' })
  today(@CurrentUser() user: JwtPayload) {
    return this.child.today(user.userId);
  }
}

@ApiTags('School attendance (parent)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('PARENT')
@Controller('parent/school')
export class AttendanceParentController {
  constructor(private readonly parent: AttendanceParentService) {}

  @Post('early-exits')
  @ApiOperation({ summary: 'Erta ketish so\'rovi (bugun) — maktab xodimi qaror qiladi' })
  requestEarlyExit(@CurrentUser() user: JwtPayload, @Body() body: unknown) {
    return this.parent.requestEarlyExit(user.userId, body);
  }

  @Get('early-exits')
  @ApiOperation({ summary: 'Bog\'langan farzandlar bo\'yicha erta ketish so\'rovlari' })
  earlyExits(@CurrentUser() user: JwtPayload) {
    return this.parent.listEarlyExits(user.userId);
  }

  @Get('attendance')
  @ApiOperation({ summary: 'Farzandning oylik davomati (?studentId=&month=YYYY-MM)' })
  attendance(@CurrentUser() user: JwtPayload, @Query() query: unknown) {
    return this.parent.monthAttendance(user.userId, query);
  }
}
