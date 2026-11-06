// Bolaning "ma'lumotlarimni o'chiring" so'rovi (Men I09). Hech narsa avtomatik o'chmaydi: so'rov saqlanadi va
// ota-ona hamda (bola maktabga bog'langan bo'lsa) maktab rahbariyati xabardor qilinadi.
// Takroriy so'rov: oxirgi 30 kunda RECEIVED so'rov bor bo'lsa — o'shani qaytaradi (yangi qator va xabar yo'q).
// Parallel so'rovlar bola qatorini qulflash orqali ketma-ketlashtiriladi.
// Maktab rahbariyatiga saqlangan bildirishnoma so'rov bilan BIR tranzaksiyada yoziladi (yo'qolmaydi) va takroriy
// so'rovda idempotent qayta yoziladi; ota-onaga push va audit esa best-effort.

import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ChildDataDeletionRequest } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { DataDeletionNotifyService } from './data-deletion-notify.service';
import { upsertDeletionStaffNotification } from './data-deletion-staff';

/** Shu muddat ichidagi RECEIVED so'rov takroriy so'rovga javob bo'ladi. */
export const DELETION_REQUEST_REUSE_DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface DeletionRequestView {
  id: string;
  status: 'RECEIVED' | 'CLOSED';
  createdAt: string;
}

export function toDeletionRequestView(r: Pick<ChildDataDeletionRequest, 'id' | 'status' | 'createdAt'>): DeletionRequestView {
  return { id: r.id, status: r.status, createdAt: r.createdAt.toISOString() };
}

@Injectable()
export class DataDeletionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notify: DataDeletionNotifyService,
  ) {}

  /** `created: false` — mavjud so'rov qaytdi (HTTP 200); `true` — yangisi yaratildi (201). */
  async create(
    childId: string,
    userId: string,
    now: Date = new Date(),
  ): Promise<{ created: boolean; request: DeletionRequestView }> {
    const child = await this.prisma.child.findUnique({ where: { id: childId }, select: { id: true, parentId: true, childUserId: true } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.childUserId !== userId) throw new ForbiddenException('Forbidden');

    const outcome = await this.prisma.$transaction(async (tx) => {
      // Bir bolaning parallel so'rovlari shu qatorda navbatga turadi — dublikat va ikki marta xabar bo'lmaydi.
      await tx.$queryRaw`SELECT id FROM children WHERE id = ${childId} FOR UPDATE`;
      const existing = await tx.childDataDeletionRequest.findFirst({
        where: { childId, status: 'RECEIVED', createdAt: { gte: new Date(now.getTime() - DELETION_REQUEST_REUSE_DAYS * DAY_MS) } },
        orderBy: { createdAt: 'desc' },
      });
      const row = existing ?? (await tx.childDataDeletionRequest.create({ data: { childId } }));
      // Idempotent: takroriy so'rovda ham qayta bajariladi — avval yo'qolgan bildirishnoma tiklanadi.
      await upsertDeletionStaffNotification(tx, row);
      return { created: !existing, row };
    });

    if (outcome.created) {
      await this.notify.afterCreate({
        requestId: outcome.row.id,
        childId,
        parentId: child.parentId,
        actorUserId: userId,
      });
    }
    return { created: outcome.created, request: toDeletionRequestView(outcome.row) };
  }

  /** Eng so'nggi so'rov yoki `null` (bola yoki uning ota-onasi). */
  async latest(childId: string, userId: string): Promise<DeletionRequestView | null> {
    const child = await this.prisma.child.findUnique({ where: { id: childId }, select: { parentId: true, childUserId: true } });
    if (!child) throw new NotFoundException('Child not found');
    if (child.parentId !== userId && child.childUserId !== userId) throw new ForbiddenException('Forbidden');
    const row = await this.prisma.childDataDeletionRequest.findFirst({ where: { childId }, orderBy: { createdAt: 'desc' } });
    return row ? toDeletionRequestView(row) : null;
  }
}
