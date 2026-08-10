import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Checkout so'rovlarini IP emas, foydalanuvchi (userId) bo'yicha cheklaydi.
 *
 * Nega IP emas: mobil operatorlar odatda CGNAT ishlatadi — bitta IP ortida
 * yuzlab foydalanuvchi bo'lishi mumkin, IP-based limit ularni bir-biriga
 * bog'lab, haqiqiy mijozlarni xato bloklab qo'yishi mumkin edi.
 *
 * Kelib chiqishi: Uzum IB (Информационная безопасность) talabiga javoban —
 * "способы ограничения и контроля рисков мошеннических операций" (2026-08-05).
 * Checkout endpoint'ga 10 daqiqada max 5 urinish (payments.controller.ts,
 * @Throttle({ checkout: ... })) — brute-force/karta-tekshiruv skriptlariga
 * qarshi.
 */
@Injectable()
export class CheckoutThrottlerGuard extends ThrottlerGuard {
  protected async getTracker(req: Record<string, any>): Promise<string> {
    const userId = (req as { user?: { userId?: string } }).user?.userId;
    return userId ? `user:${userId}` : `ip:${req.ip}`;
  }
}
