// Admin RBAC — permission tekshiruvi (Sprint 6 — P0 xavfsizlik).
//
// staffAuthGuard'dan KEYIN ishlaydi (u request.staff'ni o'rnatadi).
// Moderatorning permission'larini DB'dan o'qiydi — JWT'da permission yo'q,
// shuning uchun ruxsat o'zgarishi darhol kuchga kiradi. Bu, shuningdek,
// bloklangan moderatorni har so'rovda tekshiradi (token 15 daqiqa amal qilsa ham).
//
// Foydalanish:
//   fastify.addHook('preHandler', staffAuthGuard);
//   fastify.addHook('preHandler', requirePermission('manage_monetization'));
//
// Bir nechta permission berilsa — "any-of" (kamida bittasi yetarli).
// Hech qanday permission berilmasa — faqat super_admin uchun.

import { FastifyReply, FastifyRequest } from 'fastify';
import { prisma } from '../lib/prisma';
import type { AdminPermission } from '../lib/admin-permissions';

export function requirePermission(...permissions: AdminPermission[]) {
  return async function permissionGuard(
    request: FastifyRequest,
    reply: FastifyReply,
  ): Promise<void> {
    const staff = request.staff;
    if (!staff) {
      reply.code(401).send({ error: 'Unauthorized' });
      return;
    }

    const moderator = await prisma.moderator.findUnique({
      where: { id: staff.sub },
      select: { status: true, moderatorRoleKey: true, permissions: true },
    });
    if (!moderator) {
      reply.code(401).send({ error: 'Moderator topilmadi' });
      return;
    }
    if (moderator.status !== 'active') {
      reply.code(403).send({ error: 'Hisob bloklangan' });
      return;
    }

    // super_admin — har doim to'liq ruxsat.
    if (moderator.moderatorRoleKey === 'super_admin') return;

    // Permission ko'rsatilmagan endpoint — faqat super_admin uchun.
    if (permissions.length === 0) {
      reply.code(403).send({ error: 'Faqat super admin uchun' });
      return;
    }

    const hasAny = permissions.some((p) => moderator.permissions.includes(p));
    if (!hasAny) {
      reply.code(403).send({ error: 'Ruxsat yetarli emas' });
      return;
    }
  };
}
