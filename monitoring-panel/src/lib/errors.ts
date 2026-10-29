import type { TKey } from '@/i18n';

/**
 * Xatoni foydalanuvchiga ko'rsatiladigan tarjima kalitiga aylantirish. Panel faqat
 * o'qiydi (demo model yoki GET so'rovlar), shuning uchun hozircha yagona kalit.
 */
export function errorKey(error?: unknown): TKey {
  void error;
  return 'errors.load';
}
