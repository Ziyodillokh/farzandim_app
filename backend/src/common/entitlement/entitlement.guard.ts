import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { EntitlementService } from './entitlement.service';
import { REQUIRE_FEATURE_KEY } from './require-feature.decorator';

/**
 * `@RequireFeature('key')` belgilangan endpoint'larni tarif bo'yicha himoyalaydi.
 * ConsumerJwtAuthGuard'DAN KEYIN ishlashi kerak (req.user allaqachon o'rnatilgan).
 * Funksiya tarifda bo'lmasa 403 (code: FEATURE_NOT_IN_PLAN) — ilova buni tutib
 * "tarifni yuksalting" oynasini ko'rsatadi.
 */
@Injectable()
export class EntitlementGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly entitlement: EntitlementService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const feature = this.reflector.getAllAndOverride<string | undefined>(
      REQUIRE_FEATURE_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!feature) return true; // talab yo'q

    const req = context
      .switchToHttp()
      .getRequest<{ user?: { userId?: string } }>();
    const userId = req.user?.userId;
    if (!userId) throw new ForbiddenException('Autentifikatsiya talab qilinadi');

    const ok = await this.entitlement.hasFeature(userId, feature);
    if (!ok) {
      throw new ForbiddenException({
        message: "Bu funksiya sizning tarifingizda mavjud emas",
        code: 'FEATURE_NOT_IN_PLAN',
        feature,
      });
    }
    return true;
  }
}
