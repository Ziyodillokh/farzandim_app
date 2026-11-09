import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { FastifyRequest } from 'fastify';
import { CurrentUser, Roles } from '../../common/decorators';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { isMultipartRequest, readImageUpload } from '../homework/homework-upload';
import { ParentSchoolCommsService } from './parent-school-comms.service';
import { MAX_RECEIPT_PHOTOS } from './receipt-photo';

/** Parvoz Parents: maktab e'lonlari, to'lov eslatmalari, tekshiruv so'rovlari. */
@ApiTags('School comms (parent)')
@ApiBearerAuth('consumer-jwt')
@UseGuards(ConsumerJwtAuthGuard, RolesGuard)
@Roles('PARENT')
@Controller('parent/school')
export class ParentSchoolCommsController {
  constructor(private readonly comms: ParentSchoolCommsService) {}

  @Get('announcements')
  @ApiOperation({ summary: "Menga yuborilgan maktab e'lonlari (sahifalangan) + o'qilmaganlar soni" })
  announcements(@CurrentUser() user: JwtPayload, @Query() query: Record<string, unknown>) {
    return this.comms.announcements(user.userId, query);
  }

  @Post('announcements/:id/read')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "E'lon o'qildi" })
  read(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.comms.markRead(user.userId, id);
  }

  @Get('payments')
  @ApiOperation({ summary: "To'lov eslatmalarim (maktab tasdiqlagan keyingi sana)" })
  payments(@CurrentUser() user: JwtPayload) {
    return this.comms.payments(user.userId);
  }

  @Get('verifications')
  @ApiOperation({ summary: "Tekshiruv so'rovlarim (maktab javobi bilan)" })
  verifications(@CurrentUser() user: JwtPayload) {
    return this.comms.verifications(user.userId);
  }

  @Post('verifications')
  @ApiConsumes('application/json', 'multipart/form-data')
  @ApiOperation({
    summary: "\"To'laganman, tekshiring\" so'rovi; onlayn to'lovda chek rasmi (multipart: `receipt` + `paymentReminderId`, `message`)",
  })
  async createVerification(@CurrentUser() user: JwtPayload, @Body() body: unknown, @Req() req: FastifyRequest) {
    if (!isMultipartRequest(req)) return this.comms.createVerification(user.userId, body);
    const { photos, raw } = await readImageUpload(req, MAX_RECEIPT_PHOTOS);
    return this.comms.createVerification(user.userId, { paymentReminderId: raw.paymentReminderId, message: raw.message }, photos[0]);
  }
}
