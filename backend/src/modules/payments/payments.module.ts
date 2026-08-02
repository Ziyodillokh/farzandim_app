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

@Module({
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
  ],
  exports: [PaymentsService, PaymentProviderRegistry],
})
export class PaymentsModule {}
