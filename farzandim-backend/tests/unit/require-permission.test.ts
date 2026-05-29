import { describe, expect, test, vi, beforeEach } from 'vitest';
import type { FastifyReply, FastifyRequest } from 'fastify';

// prisma'ni mock qilamiz — RBAC guard DB'ga bormaydi, test izolyatsiyalangan.
vi.mock('../../src/lib/prisma', () => ({
  prisma: { moderator: { findUnique: vi.fn() } },
}));

import { prisma } from '../../src/lib/prisma';
import { requirePermission } from '../../src/middleware/require-permission';

const findUnique = prisma.moderator.findUnique as unknown as ReturnType<typeof vi.fn>;

interface FakeReply {
  statusCode: number;
  body: unknown;
  code(c: number): FakeReply;
  send(b: unknown): FakeReply;
}

function makeReply(): FakeReply {
  const reply: FakeReply = {
    statusCode: 0,
    body: undefined,
    code(c) {
      reply.statusCode = c;
      return reply;
    },
    send(b) {
      reply.body = b;
      return reply;
    },
  };
  return reply;
}

function makeModerator(
  over: Partial<{ status: string; moderatorRoleKey: string; permissions: string[] }> = {},
) {
  return {
    status: over.status ?? 'active',
    moderatorRoleKey: over.moderatorRoleKey ?? 'custom',
    permissions: over.permissions ?? [],
  };
}

/** Guard'ni soxta request/reply bilan ishga tushiradi va reply'ni qaytaradi. */
async function run(
  guard: ReturnType<typeof requirePermission>,
  staffSub: string | null,
): Promise<FakeReply> {
  const reply = makeReply();
  const request = {
    staff: staffSub ? { sub: staffSub } : undefined,
  } as unknown as FastifyRequest;
  await guard(request, reply as unknown as FastifyReply);
  return reply;
}

beforeEach(() => {
  findUnique.mockReset();
});

describe('requirePermission — admin RBAC guard (C5)', () => {
  test("request.staff yo'q — 401", async () => {
    const reply = await run(requirePermission('manage_monetization'), null);
    expect(reply.statusCode).toBe(401);
  });

  test("moderator DB'da topilmasa — 401", async () => {
    findUnique.mockResolvedValue(null);
    const reply = await run(requirePermission('manage_monetization'), 'm-1');
    expect(reply.statusCode).toBe(401);
  });

  test('bloklangan moderator — 403', async () => {
    findUnique.mockResolvedValue(makeModerator({ status: 'blocked' }));
    const reply = await run(requirePermission('manage_monetization'), 'm-1');
    expect(reply.statusCode).toBe(403);
  });

  test("super_admin — har doim o'tadi", async () => {
    findUnique.mockResolvedValue(makeModerator({ moderatorRoleKey: 'super_admin' }));
    const reply = await run(requirePermission('manage_monetization'), 'm-1');
    expect(reply.statusCode).toBe(0);
  });

  test("kerakli permission bor — o'tadi", async () => {
    findUnique.mockResolvedValue(makeModerator({ permissions: ['manage_monetization'] }));
    const reply = await run(requirePermission('manage_monetization'), 'm-1');
    expect(reply.statusCode).toBe(0);
  });

  test("C5 — faqat o'qish ruxsatli moderator yozish guard'ida 403", async () => {
    // view_payments — o'qish ruxsati; manage_monetization — yozish guard'i.
    findUnique.mockResolvedValue(makeModerator({ permissions: ['view_payments'] }));
    const reply = await run(requirePermission('manage_monetization'), 'm-1');
    expect(reply.statusCode).toBe(403);
  });

  test('any-of — ko\'p ruxsatdan bittasi yetarli', async () => {
    findUnique.mockResolvedValue(makeModerator({ permissions: ['view_payments'] }));
    const reply = await run(
      requirePermission('manage_monetization', 'view_payments'),
      'm-1',
    );
    expect(reply.statusCode).toBe(0);
  });

  test("permissionsiz guard — super_admin'dan boshqaga 403", async () => {
    findUnique.mockResolvedValue(makeModerator({ permissions: ['manage_monetization'] }));
    const reply = await run(requirePermission(), 'm-1');
    expect(reply.statusCode).toBe(403);
  });
});
