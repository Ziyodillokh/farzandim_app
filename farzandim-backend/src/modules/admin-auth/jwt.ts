import jwt from 'jsonwebtoken';
import { env } from '../../config/env';

const ADMIN_AUDIENCE = 'admin-panel';
const ADMIN_ISSUER = 'farzandim-backend';

export interface AdminJwtPayload {
  sub: string;            // Moderator.id
  email: string;
  role: string;           // moderatorRoleKey, e.g. "super_admin"
  /** Sprint 6 P1 — logout'da increment; refresh tokenVersion mosligini tekshiradi. */
  tokenVersion?: number;
}

interface AdminTokenClaims extends AdminJwtPayload {
  aud: string;
  iss: string;
}

export function signAdminAccessToken(payload: AdminJwtPayload): string {
  return jwt.sign(payload, env.ADMIN_JWT_ACCESS_SECRET, {
    expiresIn: env.ADMIN_JWT_ACCESS_EXPIRES as any,
    audience: ADMIN_AUDIENCE,
    issuer: ADMIN_ISSUER,
  });
}

export function signAdminRefreshToken(payload: AdminJwtPayload): string {
  return jwt.sign(payload, env.ADMIN_JWT_REFRESH_SECRET, {
    expiresIn: env.ADMIN_JWT_REFRESH_EXPIRES as any,
    audience: ADMIN_AUDIENCE,
    issuer: ADMIN_ISSUER,
  });
}

export function verifyAdminAccessToken(token: string): AdminJwtPayload {
  return jwt.verify(token, env.ADMIN_JWT_ACCESS_SECRET, {
    audience: ADMIN_AUDIENCE,
    issuer: ADMIN_ISSUER,
  }) as AdminTokenClaims;
}

export function verifyAdminRefreshToken(token: string): AdminJwtPayload {
  return jwt.verify(token, env.ADMIN_JWT_REFRESH_SECRET, {
    audience: ADMIN_AUDIENCE,
    issuer: ADMIN_ISSUER,
  }) as AdminTokenClaims;
}
