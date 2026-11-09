import { Controller, Get, Header, Param, Query, Res, StreamableFile } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { FastifyReply } from 'fastify';
import { Public } from '../../common/decorators';
import { ReceiptService } from './receipt.service';

/**
 * To'lov cheki rasmi proksisi: autentifikatsiyasiz, lekin imzolangan havola (`?exp=&sig=`) bilan.
 * `<img>` Authorization yubora olmaydi; havolani faqat server (xodim paneli ro'yxati) beradi.
 */
@ApiTags('School - Payments')
@Controller('school/verifications/receipts')
export class ReceiptController {
  constructor(private readonly receipts: ReceiptService) {}

  @Get(':verificationId')
  @Public()
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: "To'lov cheki rasmi (imzolangan havola)" })
  async receipt(
    @Param('verificationId') verificationId: string,
    @Res({ passthrough: true }) reply: FastifyReply,
    @Query('exp') exp?: string,
    @Query('sig') sig?: string,
  ) {
    const object = await this.receipts.read(verificationId, exp, sig);
    // Faqat muvaffaqiyatli javob keshlanadi (403/404/503 emas).
    reply.header('Cache-Control', 'private, max-age=3600');
    return new StreamableFile(object.body, { type: object.contentType });
  }
}
