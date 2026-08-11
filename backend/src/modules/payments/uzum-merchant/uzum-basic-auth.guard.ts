import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { timingSafeEqual } from 'crypto';
import { EnvConfig } from '../../../common/config/env.schema';

/**
 * Uzum Merchant API uchun HTTP Basic auth.
 *
 * Login/parol BIZ tomonimizdan belgilanadi (`.env`) va Uzum'ga beriladi.
 * Env bo'sh bo'lsa HAR QANDAY so'rov rad etiladi — ya'ni sozlanmaguncha
 * endpointlar amalda yopiq (deploy xavfsiz).
 */
@Injectable()
export class UzumBasicAuthGuard implements CanActivate {
  private readonly logger = new Logger(UzumBasicAuthGuard.name);
  private readonly username: string;
  private readonly password: string;

  constructor(config: ConfigService<EnvConfig, true>) {
    this.username =
      config.get('UZUM_MERCHANT_USERNAME', { infer: true }) ?? '';
    this.password =
      config.get('UZUM_MERCHANT_PASSWORD', { infer: true }) ?? '';
  }

  canActivate(context: ExecutionContext): boolean {
    if (!this.username || !this.password) {
      this.logger.warn(
        'Uzum Merchant API sozlanmagan (UZUM_MERCHANT_USERNAME/PASSWORD) — so\'rov rad etildi',
      );
      throw new UnauthorizedException('Uzum merchant API not configured');
    }

    const request = context.switchToHttp().getRequest<{
      headers: Record<string, string | string[] | undefined>;
    }>();
    const header = request.headers['authorization'];
    const raw = Array.isArray(header) ? header[0] : header;
    const [scheme, token] = (raw ?? '').split(' ');

    if (scheme !== 'Basic' || !token) {
      throw new UnauthorizedException('Basic authorization required');
    }

    let decoded = '';
    try {
      decoded = Buffer.from(token, 'base64').toString('utf8');
    } catch {
      throw new UnauthorizedException('Malformed Basic token');
    }

    // Parolning o'zida ':' bo'lishi mumkin — faqat BIRINCHI ':' bo'yicha
    // ajratamiz (`split(':')` bilan parol kesilib qolardi).
    const sep = decoded.indexOf(':');
    if (sep < 0) throw new UnauthorizedException('Malformed Basic token');
    const user = decoded.slice(0, sep);
    const pass = decoded.slice(sep + 1);

    if (!this.safeEqual(user, this.username) ||
        !this.safeEqual(pass, this.password)) {
      this.logger.warn('Uzum Merchant API: noto\'g\'ri login/parol');
      throw new UnauthorizedException('Invalid credentials');
    }

    return true;
  }

  /** Timing-attack'ga chidamli solishtiruv (uzunlik farqi ham sizdirmaydi). */
  private safeEqual(a: string, b: string): boolean {
    const bufA = Buffer.from(a, 'utf8');
    const bufB = Buffer.from(b, 'utf8');
    if (bufA.length !== bufB.length) return false;
    return timingSafeEqual(bufA, bufB);
  }
}
