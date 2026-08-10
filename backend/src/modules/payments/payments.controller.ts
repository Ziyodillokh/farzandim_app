import {
  Controller,
  Get,
  Post,
  Body,
  Req,
  Res,
  HttpCode,
  HttpStatus,
  UseGuards,
  Logger,
  BadGatewayException,
  BadRequestException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { ConsumerJwtAuthGuard, RolesGuard } from '../../common/guards';
import { CurrentUser, Public } from '../../common/decorators';
import { JwtPayload } from '../../common/interfaces/jwt-payload.interface';
import { PrismaService } from '../../common/database/prisma.service';
import { PaymentsService } from './payments.service';
import { AppleIapService } from './apple-iap.service';
import { PaymentProviderRegistry } from './providers/registry';
import { WebhookIpGuard } from './guards/webhook-ip.guard';
import { CheckoutThrottlerGuard } from './guards/checkout-throttler.guard';
import { CheckoutDto } from './dto/checkout.dto';
import { AppleVerifyDto } from './dto/apple-verify.dto';
import type { PaymentProviderKey, WebhookRequest } from './providers/types';
import type { FastifyRequest, FastifyReply } from 'fastify';

@ApiTags('Payments')
@Controller('payments')
export class PaymentsController {
  private readonly logger = new Logger(PaymentsController.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly paymentsService: PaymentsService,
    private readonly appleIap: AppleIapService,
    private readonly registry: PaymentProviderRegistry,
  ) {}

  @Get('plans')
  @ApiBearerAuth()
  @UseGuards(ConsumerJwtAuthGuard, RolesGuard)
  @ApiOperation({ summary: 'List active plans and available providers' })
  async getPlans() {
    const plans = await this.prisma.plan.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
    });
    return {
      plans: plans.map((p) => ({
        id: p.id,
        slug: p.slug,
        name: p.name,
        description: p.description,
        priceUzs: p.priceUzs,
        period: p.period,
        entitlementTier: p.entitlementTier,
        badge: p.badge,
        features: p.features,
      })),
      availableProviders: this.registry.getAvailableProviderKeys(),
    };
  }

  @Get('me')
  @ApiBearerAuth()
  @UseGuards(ConsumerJwtAuthGuard, RolesGuard)
  @ApiOperation({ summary: 'Current subscription and payment history' })
  async getMe(@CurrentUser() user: JwtPayload) {
    const [subscription, payments] = await Promise.all([
      this.paymentsService.getActiveSubscription(user.userId),
      this.prisma.payment.findMany({
        where: { userId: user.userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);
    return {
      subscription: subscription
        ? {
            id: subscription.id,
            status: subscription.status,
            planName: subscription.plan?.name ?? null,
            entitlementTier: subscription.plan?.entitlementTier ?? 'free',
            startedAt: subscription.startedAt?.toISOString() ?? null,
            expiresAt: subscription.expiresAt?.toISOString() ?? null,
          }
        : null,
      payments: payments.map((p) => ({
        id: p.id,
        planName: p.planName,
        amount: p.amount,
        method: p.method,
        status: p.status,
        createdAt: p.createdAt.toISOString(),
        paidAt: p.paidAt?.toISOString() ?? null,
      })),
    };
  }

  @Post('checkout')
  @ApiBearerAuth()
  // Uzum IB anti-fraud talabi: 10 daqiqada foydalanuvchi boshiga max 5
  // urinish (guard tartibi muhim — JWT avval ishlashi kerak, shunda
  // CheckoutThrottlerGuard req.user.userId'ni ko'radi, IP'ga tushmaydi).
  @Throttle({ checkout: { limit: 5, ttl: 600_000 } })
  @UseGuards(ConsumerJwtAuthGuard, RolesGuard, CheckoutThrottlerGuard)
  @ApiOperation({ summary: 'Start payment checkout' })
  async checkout(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CheckoutDto,
  ) {
    const providerKey = dto.provider as PaymentProviderKey;

    if (!this.registry.isProviderAvailable(providerKey)) {
      throw new ServiceUnavailableException(
        `Payment provider "${dto.provider}" is not available`,
      );
    }

    const plan = await this.prisma.plan.findUnique({
      where: { id: dto.planId },
    });
    if (!plan || !plan.isActive) {
      throw new NotFoundException('Plan not found');
    }
    if (plan.priceUzs <= 0) {
      throw new BadRequestException('Free plan does not require payment');
    }

    // Yillik = oylik narx × 10 (2 oy tekin). Oylik plan tanlansa ham yillik
    // sotib olsa bo'ladi — summa shundan kelib chiqib hisoblanadi. Obuna
    // muddati esa activateSubscriptionTx'da summadan aniqlanadi (365 kun).
    const isYearly = dto.billingPeriod === 'yearly';
    const amount = isYearly ? plan.priceUzs * 10 : plan.priceUzs;

    const payment = await this.prisma.payment.create({
      data: {
        userId: user.userId,
        planId: plan.id,
        planName: plan.name,
        amount,
        method: dto.provider,
        status: 'pending',
      },
    });

    try {
      const checkout = await this.registry
        .getProvider(providerKey)
        .createCheckout({
          paymentId: payment.id,
          amount: payment.amount,
          planName: plan.name,
        });
      return {
        paymentId: payment.id,
        provider: checkout.provider,
        checkoutUrl: checkout.checkoutUrl,
      };
    } catch (err) {
      this.logger.error('Checkout creation failed', err);
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: 'failed', notes: 'Checkout creation failed' },
      });
      throw new BadGatewayException('Could not open payment page');
    }
  }

  @Post('apple/verify')
  @ApiBearerAuth()
  @UseGuards(ConsumerJwtAuthGuard, RolesGuard)
  @ApiOperation({ summary: 'Verify Apple IAP purchase and grant subscription' })
  async appleVerify(
    @CurrentUser() user: JwtPayload,
    @Body() dto: AppleVerifyDto,
  ) {
    return this.appleIap.verify(user.userId, dto);
  }

  @Post('webhook/payme')
  @Public()
  @UseGuards(WebhookIpGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Payme webhook (no auth, signature verified)' })
  async webhookPayme(@Req() req: FastifyRequest, @Res() res: FastifyReply) {
    await this.runWebhook('payme', req, res);
  }

  @Post('webhook/click')
  @Public()
  @UseGuards(WebhookIpGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Click webhook (no auth, signature verified)' })
  async webhookClick(@Req() req: FastifyRequest, @Res() res: FastifyReply) {
    await this.runWebhook('click', req, res);
  }

  @Post('webhook/uzum')
  @Public()
  @UseGuards(WebhookIpGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Uzum webhook (no auth, signature verified)' })
  async webhookUzum(@Req() req: FastifyRequest, @Res() res: FastifyReply) {
    await this.runWebhook('uzum', req, res);
  }

  private async runWebhook(
    providerKey: PaymentProviderKey,
    req: FastifyRequest,
    res: FastifyReply,
  ) {
    const provider = this.registry.getProvider(providerKey);
    if (!provider.isConfigured()) {
      await res.status(404).send({ error: 'Provider not available' });
      return;
    }

    const webhookReq: WebhookRequest = {
      body: req.body,
      rawBody:
        typeof req.body === 'string'
          ? req.body
          : JSON.stringify(req.body ?? ''),
      headers: req.headers as Record<string, string | undefined>,
      query: (req.query ?? {}) as Record<string, unknown>,
    };

    try {
      const result = await provider.handleWebhook(webhookReq);
      await res.status(result.status).send(result.body);
    } catch (err) {
      this.logger.error(`Webhook ${providerKey} error`, err);
      await res.status(500).send({ error: 'Webhook processing failed' });
    }
  }
}
