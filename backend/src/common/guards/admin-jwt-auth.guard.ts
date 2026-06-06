import {
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { SecuritySettingsService } from '../security/security-settings.service';
import { getClientIp } from '../helpers/client-ip';

@Injectable()
export class AdminJwtAuthGuard extends AuthGuard('admin-jwt') {
  constructor(private readonly security: SecuritySettingsService) {
    super();
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // 1) JWT tekshiruvi (passport) — request.user'ni o'rnatadi.
    const ok = (await super.canActivate(context)) as boolean;
    if (!ok) return false;

    // 2) IP allowlist enforcement — yoqilgan bo'lsa, ruxsat etilmagan IP'dan
    // har qanday admin so'rovi 403 oladi.
    const req = context.switchToHttp().getRequest();
    const ip = getClientIp(req);
    if (!(await this.security.isIpAllowed(ip))) {
      throw new ForbiddenException(
        `IP manzilingiz (${ip}) admin panelga ruxsat etilmagan`,
      );
    }
    return true;
  }

  handleRequest<T>(err: Error | null, user: T): T {
    if (err || !user) {
      throw err || new UnauthorizedException('Invalid or expired admin token');
    }
    return user;
  }
}
