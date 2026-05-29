// To'lov provayderlari registri.
//
// Routes qatlami provayderlarni shu yerdan oladi — qaysi biri sozlangan
// (.env kalitlari bor) ekanini tekshiradi. Kalit yo'q provayder checkout'da
// 503 qaytaradi (FCM bilan bir xil graceful-disable pattern).

import { clickProvider } from './providers/click';
import { paymeProvider } from './providers/payme';
import { uzumProvider } from './providers/uzum';
import type { PaymentProvider, PaymentProviderKey } from './types';

const providers: Record<PaymentProviderKey, PaymentProvider> = {
  payme: paymeProvider,
  click: clickProvider,
  uzum: uzumProvider,
};

/** Berilgan kalit bo'yicha provayder (har doim mavjud — sozlanmagan bo'lishi mumkin). */
export function getProvider(key: PaymentProviderKey): PaymentProvider {
  return providers[key];
}

/** Faqat sozlangan (kalitlari bor) provayderlar. */
export function getConfiguredProviders(): PaymentProvider[] {
  return Object.values(providers).filter((p) => p.isConfigured());
}

/** Sozlangan provayderlar kalitlari — checkout API'da mijozga ko'rsatish uchun. */
export function getAvailableProviderKeys(): PaymentProviderKey[] {
  return getConfiguredProviders().map((p) => p.key);
}

/** Provayder sozlanganmi (checkout boshlash mumkinmi). */
export function isProviderAvailable(key: PaymentProviderKey): boolean {
  return providers[key].isConfigured();
}
