import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermissions = this.reflector.getAllAndOverride<string[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredPermissions || requiredPermissions.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user || !user.sub) {
      throw new ForbiddenException('Access denied');
    }

    const moderator = await this.prisma.moderator.findUnique({
      where: { id: user.sub },
      select: {
        status: true,
        moderatorRoleKey: true,
        permissions: true,
        tokenVersion: true,
      },
    });

    if (!moderator || moderator.status !== 'active') {
      throw new ForbiddenException('Account is not active');
    }

    if (
      user.tokenVersion !== undefined &&
      moderator.tokenVersion !== user.tokenVersion
    ) {
      throw new ForbiddenException('Token has been revoked');
    }

    if (moderator.moderatorRoleKey === 'super_admin') {
      return true;
    }

    const hasPermission = requiredPermissions.some((perm) =>
      moderator.permissions.includes(perm),
    );

    if (!hasPermission) {
      throw new ForbiddenException('Insufficient permissions');
    }

    return true;
  }
}
