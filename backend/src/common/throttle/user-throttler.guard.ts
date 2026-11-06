import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Limitni IP emas, foydalanuvchi (userId) bo'yicha hisoblaydi: mobil operatorlar CGNAT ortida bitta IP'da
 * yuzlab foydalanuvchi bo'lishi mumkin. JWT guard'i AVVAL ishlashi shart (aks holda `req.user` bo'sh va IP'ga tushadi):
 * `@UseGuards(ConsumerJwtAuthGuard, RolesGuard, UserThrottlerGuard)` tartibida ishlating.
 */
@Injectable()
export class UserThrottlerGuard extends ThrottlerGuard {
  protected async getTracker(req: Record<string, any>): Promise<string> {
    const userId = (req as { user?: { userId?: string } }).user?.userId;
    return userId ? `user:${userId}` : `ip:${req.ip}`;
  }
}
