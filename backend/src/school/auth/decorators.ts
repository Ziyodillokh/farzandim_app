import {
  applyDecorators,
  createParamDecorator,
  ExecutionContext,
  SetMetadata,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth } from '@nestjs/swagger';
import { SCHOOL_PERMISSIONS_KEY, SCHOOL_TEMP_PASSWORD_OK_KEY, SchoolPermission } from './permissions';
import type { SchoolActor } from './school-actor';
import { SchoolAuthGuard } from './school-auth.guard';

/** Kamida bitta ruxsat talab qilinadi (bo'sh — faqat kirgan xodim). */
export const SchoolPermissions = (...permissions: SchoolPermission[]) =>
  SetMetadata(SCHOOL_PERMISSIONS_KEY, permissions);

/** Controller / route — maktab xodimi tokeni bilan. */
export const SchoolAuth = () =>
  applyDecorators(UseGuards(SchoolAuthGuard), ApiBearerAuth('school-jwt'));

/** Vaqtinchalik parol bilan ham ishlaydigan yo'l (qolganlari parol almashtirilguncha 403). */
export const AllowTempPassword = () => SetMetadata(SCHOOL_TEMP_PASSWORD_OK_KEY, true);

export const Actor = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): SchoolActor =>
    ctx.switchToHttp().getRequest<{ schoolActor: SchoolActor }>().schoolActor,
);
