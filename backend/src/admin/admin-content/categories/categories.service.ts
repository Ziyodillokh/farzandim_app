import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../common/database/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  private rowOf(c: { id: string; kind: string; slug: string; name: string; sortOrder: number }) {
    return { id: c.id, kind: c.kind, slug: c.slug, name: c.name, sortOrder: c.sortOrder };
  }

  async list(kind?: string) {
    const where: Prisma.ContentCategoryWhereInput = {};
    if (kind) where.kind = kind;
    const rows = await this.prisma.contentCategory.findMany({
      where,
      orderBy: [{ kind: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
    });
    return rows.map((r) => this.rowOf(r));
  }

  async create(dto: CreateCategoryDto) {
    try {
      const created = await this.prisma.contentCategory.create({
        data: {
          kind: dto.kind,
          slug: dto.slug,
          name: dto.name,
          sortOrder: dto.sortOrder ?? 0,
        },
      });
      return this.rowOf(created);
    } catch (err: any) {
      if (err?.code === 'P2002') {
        throw new ConflictException('Category with this kind+slug already exists');
      }
      throw err;
    }
  }

  async update(id: string, dto: Partial<CreateCategoryDto>) {
    const updates: Prisma.ContentCategoryUpdateInput = {};
    if (dto.name !== undefined) updates.name = dto.name;
    if (dto.sortOrder !== undefined) updates.sortOrder = dto.sortOrder;
    try {
      const updated = await this.prisma.contentCategory.update({
        where: { id },
        data: updates,
      });
      return this.rowOf(updated);
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Category not found');
      throw err;
    }
  }

  async remove(id: string) {
    try {
      await this.prisma.contentCategory.delete({ where: { id } });
    } catch (err: any) {
      if (err?.code === 'P2025') throw new NotFoundException('Category not found');
      throw err;
    }
  }
}
