// ─────────────────────────────────────────────────────────────────────
// Admin audit log helper — Sprint 5.x
// ─────────────────────────────────────────────────────────────────────
//
// Har admin amalini AuditLog jadval'iga yozish. Fire-and-forget pattern:
// log yozishi muvaffaqiyatsiz bo'lsa ham asosiy operatsiya buzilmaydi.
//
// Action format:
//   "<domain>.<verb>[.<result>]"
//   masalan: "auth.login.success", "auth.login.failure",
//            "auth.2fa.enable", "video.approve", "moderator.block"

import type { FastifyRequest } from 'fastify';
import { prisma } from './prisma';

export interface AuditEventInput {
  action: string;
  moderatorId?: string | null;
  email?: string | null;
  resourceType?: string | null;
  resourceId?: string | null;
  status?: 'success' | 'failure';
  details?: Record<string, unknown> | null;
}

/**
 * Audit event yozish. Fire-and-forget — caller `await` qilmasligi mumkin,
 * lekin agar await qilsa ham xavfsiz (xato tashlaydi emas, faqat log qiladi).
 */
export async function logAudit(
  request: FastifyRequest | null,
  input: AuditEventInput,
): Promise<void> {
  try {
    const ipAddress = extractIp(request);
    const userAgent = request?.headers?.['user-agent'];
    await prisma.moderatorAuditLog.create({
      data: {
        moderatorId: input.moderatorId ?? null,
        email: input.email ?? null,
        action: input.action,
        resourceType: input.resourceType ?? null,
        resourceId: input.resourceId ?? null,
        status: input.status ?? 'success',
        ipAddress: ipAddress ?? null,
        userAgent: typeof userAgent === 'string' ? userAgent.slice(0, 500) : null,
        details: input.details ? (input.details as object) : undefined,
      },
    });
  } catch (err) {
    // Audit log yozishi muvaffaqiyatsiz bo'lsa, asosiy oqimni bloklamaymiz.
    // Faqat console'ga yozamiz — kelajakda observability stack'ga ko'chiriladi.
    // eslint-disable-next-line no-console
    console.warn('[audit-log] write failed:', (err as Error).message, input);
  }
}

function extractIp(request: FastifyRequest | null): string | undefined {
  if (!request) return undefined;
  // Nginx forward — X-Forwarded-For first ip
  const fwd = request.headers['x-forwarded-for'];
  if (typeof fwd === 'string' && fwd.length > 0) {
    const first = fwd.split(',')[0]?.trim();
    if (first) return first.slice(0, 64);
  }
  if (Array.isArray(fwd) && fwd.length > 0) {
    return String(fwd[0]).split(',')[0]?.trim().slice(0, 64);
  }
  return request.ip?.slice(0, 64);
}
