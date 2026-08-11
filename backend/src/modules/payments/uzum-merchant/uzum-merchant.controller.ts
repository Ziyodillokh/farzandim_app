import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Logger,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { Public } from '../../../common/decorators';
import { UzumBasicAuthGuard } from './uzum-basic-auth.guard';
import { UzumMerchantService } from './uzum-merchant.service';

/**
 * Uzum Bank MERCHANT API — Uzum BIZGA yuboradigan so'rovlar.
 *
 * To'liq manzillar (global prefix `/api` bilan):
 *   POST /api/uzum/merchant/check
 *   POST /api/uzum/merchant/create
 *   POST /api/uzum/merchant/confirm
 *   POST /api/uzum/merchant/reverse
 *   POST /api/uzum/merchant/status
 *
 * Auth: HTTP Basic (login/parol BIZ beramiz, `.env` da).
 *
 * ⚠️ Ikki muhim texnik nuqta:
 *  1. `@Body()` turi — oddiy `Record` (DTO KLASSI EMAS). Sabab: global
 *     `ValidationPipe` `forbidNonWhitelisted: true` bilan ishlaydi va Uzum
 *     kutilmagan qo'shimcha maydon yuborsa so'rovni 400 bilan rad etardi,
 *     ustiga Nest'ning standart xato JSON'i Uzum kutgan formatda EMAS.
 *     Shuning uchun validatsiya servis ichida qo'lda, xatolar esa Uzum
 *     formatida (`status: FAILED` + `errorCode`) qaytariladi.
 *  2. Barcha javoblar HTTP 200 — xato ham. Uzum mashina o'qiydigan signalni
 *     `errorCode` dan oladi (proxy/WAF 4xx'ni buzmasin).
 */
@ApiExcludeController()
@Controller('uzum/merchant')
export class UzumMerchantController {
  private readonly logger = new Logger(UzumMerchantController.name);

  constructor(private readonly service: UzumMerchantService) {}

  @Post('check')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  @HttpCode(HttpStatus.OK)
  check(@Body() body: Record<string, unknown>) {
    this.logger.log(`check ${JSON.stringify(body)}`);
    return this.service.check(body);
  }

  @Post('create')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  @HttpCode(HttpStatus.OK)
  create(@Body() body: Record<string, unknown>) {
    this.logger.log(`create ${JSON.stringify(body)}`);
    return this.service.create(body);
  }

  @Post('confirm')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  @HttpCode(HttpStatus.OK)
  confirm(@Body() body: Record<string, unknown>) {
    this.logger.log(`confirm ${JSON.stringify(body)}`);
    return this.service.confirm(body);
  }

  @Post('reverse')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  @HttpCode(HttpStatus.OK)
  reverse(@Body() body: Record<string, unknown>) {
    this.logger.log(`reverse ${JSON.stringify(body)}`);
    return this.service.reverse(body);
  }

  @Post('status')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  @HttpCode(HttpStatus.OK)
  status(@Body() body: Record<string, unknown>) {
    this.logger.log(`status ${JSON.stringify(body)}`);
    return this.service.status(body);
  }
}
