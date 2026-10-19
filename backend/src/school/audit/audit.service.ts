// Audit jurnali (panel `auditService`): filtr, qidiruv, sahifalash bazada.
// Bola ovozi (CARE) yozuvlari faqat shaxsiy murojaatlarga ruxsati bor rolga.

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolAuditLog } from '@prisma/client';
import { z } from 'zod';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDayRange } from '../../common/time/tashkent';
import { actorCan, assertCan, SchoolActor } from '../auth/school-actor';
import { compareUz } from '../common/list-query';
import { isoDateSchema, listQuerySchema, paginate, parseOrThrow } from '../common/school-zod';

const auditFilterSchema = listQuerySchema.extend({
  module: z.string().max(20).optional(),
  actorId: z.string().max(64).optional(),
  from: isoDateSchema.optional(),
  to: isoDateSchema.optional(),
});

export function toAuditView(a: SchoolAuditLog) {
  return {
    id: a.id,
    at: a.at.toISOString(),
    actorId: a.actorId ?? '',
    actorName: a.actorName,
    module: a.module,
    action: a.action,
    entityId: a.entityId,
    summary: a.summary,
    ...(a.params && { params: a.params as Record<string, string | number> }),
    before: a.before,
    after: a.after,
  };
}

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async list(actor: SchoolActor, raw: Record<string, unknown>) {
    assertCan(actor, 'audit.view');
    const query = parseOrThrow(auditFilterSchema, raw);
    const where: Prisma.SchoolAuditLogWhereInput = {
      ...this.visible(actor),
      ...(query.module && { module: query.module }),
      ...(query.actorId && { actorId: query.actorId }),
      ...((query.from || query.to) && {
        at: {
          ...(query.from && { gte: tashkentDayRange(query.from).gte }),
          ...(query.to && { lt: tashkentDayRange(query.to).lt }),
        },
      }),
      ...(query.search && {
        OR: [
          { actorName: { contains: query.search, mode: 'insensitive' } },
          { summary: { contains: query.search, mode: 'insensitive' } },
          { action: { contains: query.search, mode: 'insensitive' } },
        ],
      }),
    };
    const dir = query.sortDir ?? 'desc';
    const orderBy: Prisma.SchoolAuditLogOrderByWithRelationInput =
      query.sortBy === 'actor'
        ? { actorName: dir }
        : query.sortBy === 'module'
          ? { module: dir }
          : { at: dir };
    const [total, rows] = await Promise.all([
      this.prisma.schoolAuditLog.count({ where }),
      this.prisma.schoolAuditLog.findMany({
        where,
        orderBy: [orderBy, { id: 'desc' }],
        skip: (query.page - 1) * query.limit,
        take: query.limit,
      }),
    ]);
    return paginate(rows.map(toAuditView), total, query);
  }

  async actors(actor: SchoolActor) {
    assertCan(actor, 'audit.view');
    const rows = await this.prisma.schoolAuditLog.groupBy({
      by: ['actorId', 'actorName'],
      where: { ...this.visible(actor), actorId: { not: null } },
    });
    const seen = new Map<string, string>();
    for (const r of rows) if (r.actorId) seen.set(r.actorId, r.actorName);
    return [...seen.entries()]
      .map(([id, name]) => ({ id, name }))
      .sort((a, b) => compareUz(a.name, b.name));
  }

  private visible(actor: SchoolActor): Prisma.SchoolAuditLogWhereInput {
    return {
      schoolId: actor.schoolId,
      ...(!actorCan(actor, 'care.individual') && { module: { not: 'CARE' } }),
    };
  }
}
