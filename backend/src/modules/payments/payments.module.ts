import { Module, forwardRef } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { AppleIapService } from './apple-iap.service';
import { PaymeProvider } from './providers/payme.provider';
import { ClickProvider } from './providers/click.provider';
import { UzumProvider } from './providers/uzum.provider';
import { PaymentProviderRegistry } from './providers/registry';
import { WebhookIpGuard } from './guards/webhook-ip.guard';
import { CheckoutThrottlerGuard } from './guards/checkout-throttler.guard';

@Module({
  // ⚠️ ThrottlerModule bu yerda EMAS — AppModule'da BIR MARTA ro'yxatdan
  // o'tadi (barcha nomli limitlar bilan). Sabab: ThrottlerModule @Global va
  // ikkinchi `forRoot()` birinchisini JIMGINA bekor qiladi — natijada
  // `checkout` limiti (5) `childPair` route'iga ham qo'llanib, Play
  // reviewer'ini 5 urinishdan keyin bloklab qo'ygan edi (2026-08-10).
  imports: [DatabaseModule],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    AppleIapService,
    PaymeProvider,
    ClickProvider,
    UzumProvider,
    PaymentProviderRegistry,
    WebhookIpGuard,
    CheckoutThrottlerGuard,
  ],
  exports: [PaymentsService, PaymentProviderRegistry],
})
export class PaymentsModule {}
