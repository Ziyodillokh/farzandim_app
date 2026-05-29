import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AdminJwtPayload } from '../interfaces/jwt-payload.interface';

/**
 * Extract the current admin/staff user from the request (set by admin JWT strategy).
 * Usage: @CurrentStaff() staff: AdminJwtPayload
 */
export const CurrentStaff = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): AdminJwtPayload => {
    const request = ctx.switchToHttp().getRequest();
    return request.user as AdminJwtPayload;
  },
);
