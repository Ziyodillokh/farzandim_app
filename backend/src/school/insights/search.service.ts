// Global qidiruv (⌘K) — rol doirasida: o'quvchilar (ism / kod), sinflar,
// xodimlar. O'zbek apostroflari bir xil (panel `matchesSearch` bilan teng).

import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { PrismaService } from '../../common/database/prisma.service';
import { actorCan, allowedClassIds, SchoolActor } from '../auth/school-actor';
import { compareUz, matchesSearch } from '../common/list-query';
import { parseOrThrow } from '../common/school-zod';

const MIN_QUERY = 2;
export const searchQuerySchema = z.object({
  q: z.string().trim().max(100).default(''),
  limit: z.coerce.number().int().min(1).max(20).default(6),
});

export interface SearchResults {
  students: Array<{ id: string; name: string; className: string; studentCode: string }>;
  classes: Array<{ id: string; name: string }>;
  staff: Array<{ id: string; name: string; position: string }>;
}

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  async query(actor: SchoolActor, input: unknown): Promise<SearchResults> {
    const { q, limit } = parseOrThrow(searchQuerySchema, input ?? {});
    if (q.length < MIN_QUERY) return { students: [], classes: [], staff: [] };
    const allowed = allowedClassIds(actor);
    const scope = allowed ? { in: allowed } : undefined;
    const [students, classes, staff] = await Promise.all([
      actorCan(actor, 'students.view')
        ? this.prisma.schoolStudent.findMany({
            where: { schoolId: actor.schoolId, archived: false, ...(scope && { classId: scope }) },
            select: { id: true, lastName: true, firstName: true, studentCode: true, class: { select: { name: true } } },
          })
        : [],
      actorCan(actor, 'classes.view')
        ? this.prisma.schoolClass.findMany({
            where: { schoolId: actor.schoolId, ...(scope && { id: scope }) },
            select: { id: true, name: true },
          })
        : [],
      actorCan(actor, 'staff.view')
        ? this.prisma.schoolStaff.findMany({ where: { schoolId: actor.schoolId }, select: { id: true, fullName: true, position: true } })
        : [],
    ]);
    return {
      students: students
        .map((s) => ({ id: s.id, name: `${s.lastName} ${s.firstName}`, className: s.class?.name ?? '', studentCode: s.studentCode }))
        .filter((s) => matchesSearch(`${s.name} ${s.studentCode}`, q))
        .sort((a, b) => compareUz(a.name, b.name))
        .slice(0, limit),
      classes: classes
        .filter((c) => matchesSearch(c.name, q))
        .sort((a, b) => compareUz(a.name, b.name))
        .slice(0, limit),
      staff: staff
        .filter((s) => matchesSearch(`${s.fullName} ${s.position}`, q))
        .sort((a, b) => compareUz(a.fullName, b.fullName))
        .slice(0, limit)
        .map((s) => ({ id: s.id, name: s.fullName, position: s.position })),
    };
  }
}
