import { Body, Controller, Logger, Post, Res, UseGuards } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import type { FastifyReply } from 'fastify';
import { Public } from '../../../common/decorators';
import { UzumBasicAuthGuard } from './uzum-basic-auth.guard';
import { UzumStatus } from './uzum-merchant.constants';
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
 * ⚠️ Uchta muhim texnik nuqta:
 *  1. `@Body()` turi — oddiy `Record` (DTO KLASSI EMAS). Sabab: global
 *     `ValidationPipe` `forbidNonWhitelisted: true` bilan ishlaydi va Uzum
 *     kutilmagan qo'shimcha maydon yuborsa so'rovni 400 bilan rad etardi,
 *     ustiga Nest'ning standart xato JSON'i Uzum kutgan formatda EMAS.
 *     Validatsiya servis ichida qo'lda, xatolar Uzum formatida.
 *  2. HTTP status: muvaffaqiyat → 200, xato → **400** (Uzum talabi,
 *     2026-08-12 da tasdiqlangan).
 *  3. Javob `@Res()` orqali TO'G'RIDAN-TO'G'RI yuboriladi. Sabab:
 *     `GlobalExceptionFilter` istalgan tashlangan xatoning tanasiga
 *     `statusCode` maydonini QO'SHIB yuboradi — bu Uzum kutgan toza
 *     formatni buzardi. `@Res()` bilan filter umuman ishtirok etmaydi.
 */
@ApiExcludeController()
@Controller('uzum/merchant')
export class UzumMerchantController {
  private readonly logger = new Logger(UzumMerchantController.name);

  constructor(private readonly service: UzumMerchantService) {}

  /** Javobni yuboradi: FAILED → HTTP 400, aks holda HTTP 200. */
  private send(reply: FastifyReply, result: { status: string }): void {
    const code = result.status === UzumStatus.Failed ? 400 : 200;
    void reply.status(code).send(result);
  }

  @Post('check')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  async check(
    @Body() body: Record<string, unknown>,
    @Res() reply: FastifyReply,
  ): Promise<void> {
    this.logger.log(`check ${JSON.stringify(body)}`);
    this.send(reply, await this.service.check(body));
  }

  @Post('create')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  async create(
    @Body() body: Record<string, unknown>,
    @Res() reply: FastifyReply,
  ): Promise<void> {
    this.logger.log(`create ${JSON.stringify(body)}`);
    this.send(reply, await this.service.create(body));
  }

  @Post('confirm')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  async confirm(
    @Body() body: Record<string, unknown>,
    @Res() reply: FastifyReply,
  ): Promise<void> {
    this.logger.log(`confirm ${JSON.stringify(body)}`);
    this.send(reply, await this.service.confirm(body));
  }

  @Post('reverse')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  async reverse(
    @Body() body: Record<string, unknown>,
    @Res() reply: FastifyReply,
  ): Promise<void> {
    this.logger.log(`reverse ${JSON.stringify(body)}`);
    this.send(reply, await this.service.reverse(body));
  }

  @Post('status')
  @Public()
  @UseGuards(UzumBasicAuthGuard)
  async status(
    @Body() body: Record<string, unknown>,
    @Res() reply: FastifyReply,
  ): Promise<void> {
    this.logger.log(`status ${JSON.stringify(body)}`);
    this.send(reply, await this.service.status(body));
  }
}
