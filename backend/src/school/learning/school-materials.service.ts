// Maktabning o'z o'quv materiallari (panel `learningService.createMaterial` …): yaratish, tahrirlash, arxivlash.
// Ruxsat — `learning.assign` (direktor, administrator, sinf rahbari, fan o'qituvchisi). Tahrirlash va arxivlash —
// muallif yoki butun maktab doirasidagi xodim (direktor / administrator). Arxivdagi material katalogda ko'rinmaydi,
// lekin yuborilgan topshiriqlar va bola ilovasi uni sarlavhasi bilan ko'rsatishda davom etadi.

import { Injectable } from '@nestjs/common';
import { SchoolLearningMaterial } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { allowedClassIds, assertCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { forbidden, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { materialInputSchema, parseSchoolMaterialId, SchoolMaterialView, toMaterialView } from './school-materials';

@Injectable()
export class SchoolMaterialsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  /** Maktab materiallari (arxivsiz) — panel katalogi uchun. */
  async list(actor: SchoolActor): Promise<SchoolMaterialView[]> {
    const rows = await this.prisma.schoolLearningMaterial.findMany({
      where: { schoolId: actor.schoolId, archived: false },
      orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
    });
    const names = await this.staffNames(actor.schoolId, rows);
    return rows.map((m) => toMaterialView(m, { byName: names.get(m.byStaffId) ?? '—', canEdit: this.canEdit(actor, m) }));
  }

  async create(actor: SchoolActor, input: unknown): Promise<SchoolMaterialView> {
    assertCan(actor, 'learning.assign');
    const data = parseOrThrow(materialInputSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const created = await tx.schoolLearningMaterial.create({
        data: { ...data, schoolId: actor.schoolId, byStaffId: actor.staffId },
      });
      await this.audit.write(
        actor,
        {
          module: 'LEARNING',
          action: 'learning.materialCreate',
          summary: `Maktab materiali qo'shildi: "${created.title}"`,
          entityId: created.id,
          after: { title: created.title, subject: created.subject, grades: created.grades },
          params: { title: created.title },
        },
        tx,
      );
      return toMaterialView(created, { byName: actor.name, canEdit: true });
    });
  }

  async update(actor: SchoolActor, materialId: string, input: unknown): Promise<SchoolMaterialView> {
    assertCan(actor, 'learning.assign');
    const existing = await this.editable(actor, materialId);
    const data = parseOrThrow(materialInputSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.schoolLearningMaterial.update({ where: { id: existing.id }, data });
      await this.audit.write(
        actor,
        {
          module: 'LEARNING',
          action: 'learning.materialUpdate',
          summary: `Maktab materiali tahrirlandi: "${updated.title}"`,
          entityId: updated.id,
          before: { title: existing.title, subject: existing.subject, grades: existing.grades },
          after: { title: updated.title, subject: updated.subject, grades: updated.grades },
          params: { title: updated.title },
        },
        tx,
      );
      const names = await this.staffNames(actor.schoolId, [updated]);
      return toMaterialView(updated, { byName: names.get(updated.byStaffId) ?? '—', canEdit: true });
    });
  }

  async archive(actor: SchoolActor, materialId: string): Promise<void> {
    assertCan(actor, 'learning.assign');
    const existing = await this.editable(actor, materialId);
    if (existing.archived) return;
    await this.prisma.$transaction(async (tx) => {
      await tx.schoolLearningMaterial.update({ where: { id: existing.id }, data: { archived: true } });
      await this.audit.write(
        actor,
        {
          module: 'LEARNING',
          action: 'learning.materialArchive',
          summary: `Maktab materiali arxivlandi: "${existing.title}"`,
          entityId: existing.id,
          params: { title: existing.title },
        },
        tx,
      );
    });
  }

  /** Topshiriq uchun: shu maktabning arxivlanmagan materiali (`school:<uuid>`) yoki `null`. */
  async resolve(schoolId: string, materialId: string): Promise<SchoolLearningMaterial | null> {
    const id = parseSchoolMaterialId(materialId);
    if (!id) return null;
    return this.prisma.schoolLearningMaterial.findFirst({ where: { id, schoolId, archived: false } });
  }

  private canEdit(actor: SchoolActor, m: SchoolLearningMaterial): boolean {
    return m.byStaffId === actor.staffId || allowedClassIds(actor) === null;
  }

  /** `school:<uuid>` yoki xom uuid; boshqa maktab / noma'lum — 404; muallif emas (sinf doirasidagi xodim) — 403. */
  private async editable(actor: SchoolActor, materialId: string): Promise<SchoolLearningMaterial> {
    const id = parseSchoolMaterialId(materialId) ?? materialId;
    const material = await this.prisma.schoolLearningMaterial.findFirst({ where: { id, schoolId: actor.schoolId } });
    if (!material) throw notFound(materialId);
    if (!this.canEdit(actor, material)) throw forbidden(materialId);
    return material;
  }

  private async staffNames(schoolId: string, rows: readonly SchoolLearningMaterial[]): Promise<Map<string, string>> {
    const ids = [...new Set(rows.map((r) => r.byStaffId))];
    if (ids.length === 0) return new Map();
    const staff = await this.prisma.schoolStaff.findMany({ where: { schoolId, id: { in: ids } }, select: { id: true, fullName: true } });
    return new Map(staff.map((s) => [s.id, s.fullName]));
  }
}
