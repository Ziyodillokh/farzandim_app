import { ExecutionContext, HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { ThrottlerGuard, ThrottlerLimitDetail } from '@nestjs/throttler';

/**
 * Standart {@link ThrottlerGuard}, lekin 429 javobi tuzilmali: `{ statusCode, code: 'RATE_LIMITED', message,
 * retryAfterSeconds }` — ilova "N soniyadan keyin urinib ko'ring" deb ko'rsata oladi.
 * Bola kirishi / tiklash so'rovlari uchun (`@Throttle({ childLogin: … })` bilan birga).
 */
@Injectable()
export class StructuredThrottlerGuard extends ThrottlerGuard {
  protected async throwThrottlingException(
    _context: ExecutionContext,
    detail: ThrottlerLimitDetail,
  ): Promise<void> {
    throw new HttpException(
      {
        code: 'RATE_LIMITED',
        message: 'Too many requests',
        retryAfterSeconds: Math.max(1, detail.timeToBlockExpire || detail.timeToExpire),
      },
      HttpStatus.TOO_MANY_REQUESTS,
    );
  }
}

/**
 * {@link StructuredThrottlerGuard}, lekin foydalanuvchi (userId) bo'yicha hisoblaydi ({@link UserThrottlerGuard} kabi): JWT
 * guard'i AVVAL ishlashi shart (`@UseGuards(ConsumerJwtAuthGuard, RolesGuard, StructuredUserThrottlerGuard)` tartibida).
 */
@Injectable()
export class StructuredUserThrottlerGuard extends StructuredThrottlerGuard {
  protected async getTracker(req: Record<string, any>): Promise<string> {
    const userId = (req as { user?: { userId?: string } }).user?.userId;
    return userId ? `user:${userId}` : `ip:${req.ip}`;
  }
}
