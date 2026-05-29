import { FastifyRequest } from 'fastify';
import { prisma } from './prisma';

export type AuditResource =
  | 'schedule'
  | 'routine'
  | 'child'
  | 'geo_zone'
  | 'notification'
  | 'feedback'
  | 'child_profile'
  | 'xp_event'
  | 'video_message'
  | 'photo_request'
  | 'sos_alert'
  | 'installed_app'
  | 'app_usage'
  | 'app_limit'
  | 'user'
  | 'auth';

export type AuditAction =
  | 'CREATE'
  | 'UPDATE'
  | 'DELETE'
  | 'TOGGLE'
  | 'RESOLVE'
  | 'LOGIN'
  | 'PAIR'
  | 'UPLOAD'
  | 'BATCH_UPSERT';

/**
 * audit_logs jadvaliga yozish. Xatolik bo'lsa ham asosiy operatsiyani buzmaydi
 * (await qilinadi, lekin try/catch bilan log'lanadi).
 *
 * `userId` opsiyasi auth flow'lari uchun (login/pair paytida request.user hali yo'q).
 */
export async function writeAudit(
  request: FastifyRequest,
  resource: AuditResource,
  action: AuditAction,
  resourceId: string,
  data?: unknown,
  options?: { userId?: string | null },
): Promise<void> {
  try {
    await prisma.auditLog.create({
      data: {
        userId: options?.userId ?? request.user?.userId ?? null,
        action: `${resource.toUpperCase()}_${action}`,
        resourceType: resource,
        resourceId,
        data: data === undefined ? undefined : (data as object),
        ipAddress: request.ip ?? null,
        userAgent: (request.headers['user-agent'] as string) ?? null,
      },
    });
  } catch (err) {
    request.log.warn({ err, resource, action, resourceId }, 'audit log write failed');
  }
}
