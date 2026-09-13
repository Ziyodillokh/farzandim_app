import { Injectable } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';

/**
 * Admin login urinishlarini cheklaydi — brute-force'ga qarshi.
 *
 * ⚠️ NEGA QO'SHILDI (2026-09-13): admin panelga kirish endpoint'ida
 * urinishlar chegarasi UMUMAN YO'Q edi. ThrottlerModule sozlangan, lekin
 * faqat `checkout` va `childPair` uchun; global ThrottlerGuard esa
 * ro'yxatdan o'tkazilmagan. Ya'ni parolni CHEKSIZ marta sinash mumkin
 * edi. Panel bolalar ma'lumotlari, to'lovlar va butun kontentni
 * boshqaradi.
 *
 * Kuzatuv IP + email bo'yicha: bitta IP'dan turli loginlarni sinash ham,
 * turli IP'lardan bitta loginni sinash ham cheklanadi. Faqat IP bo'yicha
 * kuzatish CGNAT ortidagi bir nechta adminni bir-biriga bog'lab qo'yardi;
 * faqat email bo'yicha esa login ro'yxatini sanab chiqishga yo'l qolardi.
 */
@Injectable()
export class AdminLoginThrottlerGuard extends ThrottlerGuard {
  protected async getTracker(req: Record<string, any>): Promise<string> {
    const email = (req as { body?: { email?: string } }).body?.email;
    const ip = (req as { ip?: string }).ip ?? 'unknown';
    const normalized =
      typeof email === 'string' ? email.trim().toLowerCase() : '';
    return normalized ? `admin:${ip}:${normalized}` : `admin:${ip}`;
  }
}
