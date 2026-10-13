import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EnvConfig } from '../../../common/config/env.schema';
import { getClientIp } from '../../../common/helpers/client-ip';

/**
 * IP allowlist guard for payment webhook endpoints.
 * Uses PAYMENT_WEBHOOK_IPS env variable (comma-separated).
 * If empty, all IPs are allowed (signature verification still protects).
 * Real client IP = `request.ip` (trustProxy trusts only the local nginx).
 */
@Injectable()
export class WebhookIpGuard implements CanActivate {
  private readonly logger = new Logger(WebhookIpGuard.name);
  private readonly allowedIps: string[];

  constructor(config: ConfigService<EnvConfig, true>) {
    const raw = config.get('PAYMENT_WEBHOOK_IPS', { infer: true }) ?? '';
    this.allowedIps = raw
      .split(',')
      .map((ip) => ip.trim())
      .filter(Boolean);
  }

  canActivate(context: ExecutionContext): boolean {
    if (this.allowedIps.length === 0) return true;

    // X-Forwarded-For'ni o'zimiz o'qimaymiz — chap qismi soxtalashtiriladi.
    // `request.ip` faqat lokal nginx'ga ishonadi (main.ts trustProxy).
    const clientIp = getClientIp(context.switchToHttp().getRequest());

    if (!this.allowedIps.includes(clientIp)) {
      this.logger.warn(
        `Webhook from unauthorized IP: ${clientIp} -- rejected`,
      );
      throw new ForbiddenException('Forbidden');
    }

    return true;
  }
}
