import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/prisma';
import { staffAuthGuard } from '../../middleware/staff-auth';
import { requirePermission } from '../../middleware/require-permission';

/**
 * Foydalanuvchilar (Users) admin sahifasi uchun moslashtirilgan view.
 * Ota-onalar `users` jadvalidan, bolalar `children` jadvalidan keladi
 * va admin paneli kutadigan yagona shaklga proyektsiya qilinadi.
 */

const ListQuery = z.object({
  q: z.string().trim().optional(),
  role: z.string().trim().optional(),     // 'parent' | 'child'
  status: z.string().trim().optional(),    // 'active' | 'blocked' (parent only — Child status hozircha 'active')
  plan: z.string().trim().optional(),      // Subscription model qo'shilgach ishlatiladi (hozircha ignor)
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

interface RowJson {
  id: string;
  kind: 'parent' | 'child';
  name: string;
  email: string | null;
  phone: string | null;
  role: 'PARENT' | 'CHILD';
  status: 'active' | 'blocked';
  plan: string;
  planLabel: string;
  lastActivityAt: string | null;
}

function parentRow(u: {
  id: string;
  name: string | null;
  phone: string | null;
  isActive: boolean;
  updatedAt: Date;
}): RowJson {
  return {
    id: u.id,
    kind: 'parent',
    name: u.name?.trim() || '—',
    email: null,
    phone: u.phone,
    role: 'PARENT',
    status: u.isActive ? 'active' : 'blocked',
    plan: 'free',
    planLabel: 'Free',
    lastActivityAt: u.updatedAt.toISOString(),
  };
}

function childRow(c: {
  id: string;
  name: string;
  lastSeenAt: Date | null;
  updatedAt: Date;
  childUser?: { phone: string | null } | null;
}): RowJson {
  return {
    id: c.id,
    kind: 'child',
    name: c.name,
    email: null,
    phone: c.childUser?.phone ?? null,
    role: 'CHILD',
    status: 'active',
    plan: 'free',
    planLabel: 'Free',
    lastActivityAt: (c.lastSeenAt ?? c.updatedAt).toISOString(),
  };
}

export const adminUsersRoutes: FastifyPluginAsync = async (fastify) => {
  // Sprint 6 — RBAC: butun modul auth + permission tekshiruvidan o'tadi.
  fastify.addHook('preHandler', staffAuthGuard);
  fastify.addHook(
    'preHandler',
    requirePermission('view_users', 'block_users', 'warn_users', 'edit_user_data'),
  );

  fastify.get('/', { preHandler: staffAuthGuard }, async (request, reply) => {
    const parsed = ListQuery.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.flatten() });
    }
    const { q, role, status, page, limit } = parsed.data;
    const kindFilter = role === 'parent' || role === 'PARENT'
      ? 'parent'
      : role === 'child' || role === 'CHILD'
        ? 'child'
        : null;

    const parentWhere: Prisma.UserWhereInput = { role: 'PARENT' };
    if (status === 'active') parentWhere.isActive = true;
    if (status === 'blocked') parentWhere.isActive = false;
    if (q && q.length > 0) {
      parentWhere.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { phone: { contains: q, mode: 'insensitive' } },
      ];
    }

    const childWhere: Prisma.ChildWhereInput = {};
    if (q && q.length > 0) {
      childWhere.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { childUser: { phone: { contains: q, mode: 'insensitive' } } },
      ];
    }
    // Child has no isBlocked field — status filter ignores children when blocked.
    const childAllowed = kindFilter !== 'parent' && status !== 'blocked';
    const parentAllowed = kindFilter !== 'child';

    const [parentTotal, childTotal] = await Promise.all([
      parentAllowed ? prisma.user.count({ where: parentWhere }) : Promise.resolve(0),
      childAllowed ? prisma.child.count({ where: childWhere }) : Promise.resolve(0),
    ]);
    const total = parentTotal + childTotal;
    const totalPages = Math.max(1, Math.ceil(total / limit));

    // Birga (parents + children) bo'lishi mumkin, lekin order/cursor bilan keyin
    // birlashtirib bo'lmaganligi uchun har turdan keraklicha olib qo'shib chiqamiz.
    // Asosiy buyurtma: yangiligi bo'yicha (lastActivityAt desc).
    const skip = (page - 1) * limit;
    const take = limit;
    const fetchCount = skip + take;

    const [parentRows, childRows] = await Promise.all([
      parentAllowed
        ? prisma.user.findMany({
            where: parentWhere,
            orderBy: { updatedAt: 'desc' },
            take: fetchCount,
          })
        : Promise.resolve([]),
      childAllowed
        ? prisma.child.findMany({
            where: childWhere,
            include: { childUser: { select: { phone: true } } },
            orderBy: [{ lastSeenAt: 'desc' }, { updatedAt: 'desc' }],
            take: fetchCount,
          })
        : Promise.resolve([]),
    ]);

    const combined: RowJson[] = [
      ...parentRows.map(parentRow),
      ...childRows.map(childRow),
    ]
      .sort((a, b) => {
        if (!a.lastActivityAt) return 1;
        if (!b.lastActivityAt) return -1;
        return b.lastActivityAt.localeCompare(a.lastActivityAt);
      })
      .slice(skip, skip + take);

    return reply.send({
      items: combined,
      pagination: { page, totalPages, total, limit },
    });
  });

  fastify.get('/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = await prisma.user.findUnique({
      where: { id },
      include: {
        childrenAsParent: { select: { id: true, name: true, age: true, familyCode: true } },
      },
    });
    if (!user) return reply.code(404).send({ error: 'User not found' });
    return reply.send({
      id: user.id,
      kind: 'parent',
      role: user.role,
      name: user.name?.trim() || '—',
      phone: user.phone,
      telegramId: user.telegramId,
      avatarUrl: user.avatarUrl,
      language: user.language,
      status: user.isActive ? 'active' : 'blocked',
      lastActivityAt: user.updatedAt.toISOString(),
      createdAt: user.createdAt.toISOString(),
      children: user.childrenAsParent,
      childrenCount: user.childrenAsParent.length,
    });
  });

  // Child detail uchun alohida endpoint — admin_panel API client shu yo'lda chaqiradi.
  fastify.get('/child-profiles/:id', { preHandler: staffAuthGuard }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const child = await prisma.child.findUnique({
      where: { id },
      include: {
        childUser: { select: { phone: true, telegramId: true, isActive: true } },
        parent: { select: { id: true, name: true, phone: true } },
        profile: true,
        xpEvents: { orderBy: { createdAt: 'desc' }, take: 10 },
      },
    });
    if (!child) return reply.code(404).send({ error: 'Child profile not found' });
    return reply.send({
      id: child.id,
      kind: 'child',
      name: child.name,
      age: child.age,
      gender: child.gender,
      region: child.region,
      photoPath: child.photoPath,
      familyCode: child.familyCode,
      isConnected: child.isConnected,
      lastSeenAt: child.lastSeenAt?.toISOString() ?? null,
      pairedAt: child.pairedAt?.toISOString() ?? null,
      device: {
        model: child.deviceModel,
        androidVersion: child.androidVersion,
        appVersion: child.appVersion,
        batteryLevel: child.batteryLevel,
        isCharging: child.isCharging,
        wifiName: child.wifiName,
      },
      phone: child.childUser?.phone ?? null,
      parent: child.parent,
      profile: child.profile
        ? {
            xp: child.profile.xp,
            level: child.profile.level,
            status: child.profile.status,
            streakDays: child.profile.streakDays,
            donBalance: child.profile.donBalance,
          }
        : null,
      recentXpEvents: child.xpEvents.map((e) => ({
        id: e.id,
        type: e.type,
        xpDelta: e.xpDelta,
        donDelta: e.donDelta,
        createdAt: e.createdAt.toISOString(),
      })),
      createdAt: child.createdAt.toISOString(),
    });
  });
};
