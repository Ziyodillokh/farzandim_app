import type { TKey } from '@/i18n';

/** Xatoni foydalanuvchiga ko'rsatiladigan tarjima kalitiga aylantirish (panel faqat o'qiydi). */
export function errorKey(_error: unknown): TKey {
  return 'errors.load';
}
