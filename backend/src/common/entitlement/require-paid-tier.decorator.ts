import { SetMetadata } from '@nestjs/common';

/** `PaidTierGuard` o'qiydigan metadata kaliti. */
export const REQUIRE_PAID_TIER_KEY = 'require_paid_tier';

/**
 * Endpoint faqat PULLIK tarif (standard/premium) uchun ochiq — `free` tarifda
 * 403 (`FEATURE_NOT_IN_PLAN`) qaytadi. Lokatsiya ko'rish, ilova bloklash,
 * rejim/jadval kabi funksiyalarda ishlatiladi (bular free'da yo'q).
 *
 * Misol:
 *   @UseGuards(PaidTierGuard)
 *   @RequirePaidTier()
 *   @Post('...') create(...) { ... }
 */
export const RequirePaidTier = () => SetMetadata(REQUIRE_PAID_TIER_KEY, true);
