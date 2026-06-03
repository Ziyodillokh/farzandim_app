import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { UpsertAppPermissionDto } from './dto/upsert-app-permission.dto';

@Injectable()
export class AppPermissionsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Bola shu ota-onaga tegishliligini tekshiradi. */
  private async assertParent(childId: string, userId: string) {
    const child = await this.prisma.child.findUnique({
      where: { id: childId },
    });
    if (!child) throw new NotFoundException('Bola topilmadi');
    if (child.parentId !== userId) {
      throw new ForbiddenException('Bu sizning farzandingiz emas');
    }
  }

  /**
   * Ruxsat siyosatlari ro'yxati. `permission` berilsa faqat o'sha ruxsat.
   * Yozuv yo'q ilovalar default ruxsat berilgan hisoblanadi (client tomonda).
   */
  async listByPermission(childId: string, userId: string, permission: string) {
    await this.assertParent(childId, userId);
    const policies = await this.prisma.appPermissionPolicy.findMany({
      where: {
        childId,
        ...(permission ? { permission } : {}),
      },
      select: { packageName: true, permission: true, allowed: true },
    });
    return { policies, count: policies.length };
  }

  /** Bitta ilova-ruxsat siyosatini saqlaydi (upsert). */
  async upsert(childId: string, userId: string, dto: UpsertAppPermissionDto) {
    await this.assertParent(childId, userId);
    return this.prisma.appPermissionPolicy.upsert({
      where: {
        childId_packageName_permission: {
          childId,
          packageName: dto.packageName,
          permission: dto.permission,
        },
      },
      update: { allowed: dto.allowed },
      create: {
        childId,
        packageName: dto.packageName,
        permission: dto.permission,
        allowed: dto.allowed,
      },
      select: { packageName: true, permission: true, allowed: true },
    });
  }
}
