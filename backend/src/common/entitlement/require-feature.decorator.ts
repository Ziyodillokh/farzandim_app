import { SetMetadata } from '@nestjs/common';

export const REQUIRE_FEATURE_KEY = 'require_feature';

/**
 * Endpoint uchun kerakli tarif funksiyasini belgilaydi. `EntitlementGuard`
 * shu metadata'ni o'qib, foydalanuvchi tarifida funksiya bo'lmasa 403 qaytaradi.
 *
 * Misol:
 *   @RequireFeature('weekly_report')
 *   @Get('weekly-report') ...
 */
export const RequireFeature = (feature: string) =>
  SetMetadata(REQUIRE_FEATURE_KEY, feature);
