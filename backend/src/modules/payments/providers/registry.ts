import { Injectable } from '@nestjs/common';
import { PaymeProvider } from './payme.provider';
import { ClickProvider } from './click.provider';
import { UzumProvider } from './uzum.provider';
import type { PaymentProvider, PaymentProviderKey } from './types';

@Injectable()
export class PaymentProviderRegistry {
  private readonly providers: Record<PaymentProviderKey, PaymentProvider>;

  constructor(
    payme: PaymeProvider,
    click: ClickProvider,
    uzum: UzumProvider,
  ) {
    this.providers = { payme, click, uzum };
  }

  getProvider(key: PaymentProviderKey): PaymentProvider {
    return this.providers[key];
  }

  getConfiguredProviders(): PaymentProvider[] {
    return Object.values(this.providers).filter((p) => p.isConfigured());
  }

  getAvailableProviderKeys(): PaymentProviderKey[] {
    return this.getConfiguredProviders().map((p) => p.key);
  }

  isProviderAvailable(key: PaymentProviderKey): boolean {
    return this.providers[key].isConfigured();
  }
}
