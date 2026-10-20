// Xodim profili va avatarlar (panel `profileService`).

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { actorCan, SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { forbidden, invalid, notFound } from '../common/school-errors';
import { MAX_PHOTO_CHARS, PHOTO_PATTERN } from '../common/school-schemas';

const avatarSelect = { id: true, fullName: true, role: true, photo: true, portrait: true } as const;

@Injectable()
export class ProfileService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async me(actor: SchoolActor) {
    const s = await this.prisma.schoolStaff.findUniqueOrThrow({ where: { id: actor.staffId } });
    return {
      id: s.id,
      fullName: s.fullName,
      role: s.role,
      photo: s.photo,
      portrait: s.portrait,
      position: s.position,
      phone: s.phone,
      email: s.email,
      username: s.username,
    };
  }

  /** Maktab xodimlari avatarlari (id → ma'lumot). */
  async avatars(actor: SchoolActor) {
    const staff = await this.prisma.schoolStaff.findMany({
      where: { schoolId: actor.schoolId },
      select: avatarSelect,
    });
    return Object.fromEntries(staff.map((s) => [s.id, s]));
  }

  /** Rasm yuklash / olib tashlash: o'zi yoki `staff.manage`. */
  async setPhoto(actor: SchoolActor, staffId: string, photo: unknown) {
    if (actor.staffId !== staffId && !actorCan(actor, 'staff.manage')) {
      throw forbidden('staff.photo');
    }
    if (
      photo !== null &&
      (typeof photo !== 'string' || !PHOTO_PATTERN.test(photo) || photo.length > MAX_PHOTO_CHARS)
    ) {
      throw invalid('profile.photo.invalid');
    }
    return this.prisma.$transaction(async (tx) => {
      const staff = await tx.schoolStaff.findFirst({ where: { id: staffId, schoolId: actor.schoolId } });
      if (!staff) throw notFound(staffId);
      const next = await tx.schoolStaff.update({
        where: { id: staffId },
        data: { photo },
        select: avatarSelect,
      });
      await this.audit.write(
        actor,
        {
          module: 'STAFF',
          action: photo ? 'staff.photo' : 'staff.photoRemove',
          summary: `Xodim rasmi ${photo ? 'yangilandi' : 'olib tashlandi'}: ${staff.fullName}`,
          entityId: staffId,
          params: { name: staff.fullName },
        },
        tx,
      );
      return next;
    });
  }
}
