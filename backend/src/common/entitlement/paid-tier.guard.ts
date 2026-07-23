import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { DEFAULT_TIER } from './entitlement.constants';
import { EntitlementService } from './entitlement.service';
import { REQUIRE_PAID_TIER_KEY } from './require-paid-tier.decorator';

/**
 * `@RequirePaidTier()` belgilangan endpoint'larni himoyalaydi: foydalanuvchi
 * tarifi `free` (DEFAULT_TIER) bo'lsa 403 (`FEATURE_NOT_IN_PLAN`) qaytaradi.
 * Standard/premium (aktiv obuna yoki 1-haftalik demo) — o'tadi.
 *
 * `ConsumerJwtAuthGuard`dan KEYIN ishlashi kerak (u `req.user`ni o'rnatadi),
 * shuning uchun method darajasida `@UseGuards(PaidTierGuard)` qo'yiladi.
 */
@Injectable()
export class PaidTierGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly entitlement: EntitlementService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<boolean | undefined>(
      REQUIRE_PAID_TIER_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!required) return true;

    const req = context
      .switchToHttp()
      .getRequest<{ user?: { userId?: string } }>();
    const userId = req.user?.userId;
    if (!userId) {
      throw new ForbiddenException('Autentifikatsiya talab qilinadi');
    }

    const ent = await this.entitlement.getEntitlement(userId);
    if (ent.tier === DEFAULT_TIER) {
      throw new ForbiddenException({
        message: 'Bu funksiya faqat pullik tariflarda mavjud',
        code: 'FEATURE_NOT_IN_PLAN',
        requiredTier: 'standard',
      });
    }
    return true;
  }
}
