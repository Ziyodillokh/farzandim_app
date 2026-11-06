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
