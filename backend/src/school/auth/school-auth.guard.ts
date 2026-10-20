// Maktab paneli himoyasi: access JWT → sessiya (bekor qilinmagan) → faol
// xodim (tokenVersion mos) → faol maktab; `@SchoolPermission(...)` ruxsatlari.
// Natija — `request.schoolActor`.

import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../common/database/prisma.service';
import { forbidden } from '../common/school-errors';
import {
  roleHas,
  SCHOOL_PERMISSIONS_KEY,
  SCHOOL_ROLES,
  SCHOOL_TEMP_PASSWORD_OK_KEY,
  SchoolPermission,
} from './permissions';
import { SchoolActor } from './school-actor';
import { SchoolTokensService } from './school-tokens.service';

@Injectable()
export class SchoolAuthGuard implements CanActivate {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: SchoolTokensService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{
      headers: Record<string, string | undefined>;
      ip?: string;
      schoolActor?: SchoolActor;
    }>();
    const header = request.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) throw unauthorized();
    const payload = this.tokens.verifyAccess(token);

    const session = await this.prisma.schoolStaffSession.findUnique({
      where: { id: payload.sid },
      select: {
        revokedAt: true,
        expiresAt: true,
        staff: {
          select: {
            id: true,
            schoolId: true,
            fullName: true,
            role: true,
            active: true,
            mustChangePassword: true,
            tokenVersion: true,
            classes: { select: { classId: true } },
            school: { select: { status: true } },
          },
        },
      },
    });
    const staff = session?.staff;
    if (
      !session ||
      session.revokedAt ||
      session.expiresAt < new Date() ||
      !staff ||
      staff.id !== payload.sub ||
      staff.schoolId !== payload.sch ||
      !staff.active ||
      staff.tokenVersion !== payload.tv ||
      staff.school.status !== 'ACTIVE'
    ) {
      throw unauthorized();
    }

    const actor: SchoolActor = {
      staffId: staff.id,
      schoolId: staff.schoolId,
      sessionId: payload.sid,
      name: staff.fullName,
      role: staff.role,
      scope: SCHOOL_ROLES[staff.role].scope,
      classIds: staff.classes.map((c) => c.classId),
      ip: request.ip,
    };
    request.schoolActor = actor;

    // Vaqtinchalik parol: almashtirilguncha faqat `/me` va parol almashtirish.
    const tempOk = this.reflector.getAllAndOverride<boolean | undefined>(SCHOOL_TEMP_PASSWORD_OK_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (staff.mustChangePassword && !tempOk) {
      throw new ForbiddenException({ code: 'PASSWORD_CHANGE_REQUIRED', message: 'Password change required' });
    }

    const required = this.reflector.getAllAndOverride<SchoolPermission[] | undefined>(
      SCHOOL_PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (required && required.length > 0 && !required.some((p) => roleHas(actor.role, p))) {
      throw forbidden(required.join('|'));
    }
    return true;
  }
}

function unauthorized(): UnauthorizedException {
  return new UnauthorizedException({ code: 'UNAUTHORIZED', message: 'Unauthorized' });
}
