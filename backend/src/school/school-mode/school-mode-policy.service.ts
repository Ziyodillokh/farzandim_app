// School Mode boshqaruvi (`schoolMode.manage`): siyosat, ruxsat etilgan
// ilovalar, smena qo'ng'iroq jadvali; ota-onalarga ruxsat eslatmasi
// (`schoolMode.view`). Har o'zgarishdan keyin bola qurilmalari qayta sync qiladi.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../common/database/prisma.service';
import { FcmService } from '../../common/fcm/fcm.service';
import { assertCan, assertClassInScope, SchoolActor } from '../auth/school-actor';
import { deviceChildSelect, deviceStateOf } from '../common/device-state';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { allowedAppsOf, SchoolModeStore, toPolicyView, toShiftLike } from './school-mode-store';
import { SchoolModeSyncService } from './school-mode-sync.service';
import { numberPeriods } from './school-mode-time';
import { remindText } from './school-mode.i18n';
import {
  allowedAppSchema,
  MAX_ALLOWED_APPS,
  policyPatchSchema,
  remindInputSchema,
  shiftUpdateSchema,
  smMsg,
} from './school-mode.schemas';

@Injectable()
export class SchoolModePolicyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: SchoolModeStore,
    private readonly sync: SchoolModeSyncService,
    private readonly audit: SchoolAuditService,
    private readonly fcm: FcmService,
  ) {}

  async updatePolicy(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'schoolMode.manage');
    const patch = parseOrThrow(policyPatchSchema, input);
    const before = await this.store.policy(actor.schoolId);
    if (patch.shiftIds) {
      const found = await this.prisma.schoolShift.count({ where: { schoolId: actor.schoolId, id: { in: patch.shiftIds } } });
      if (found !== new Set(patch.shiftIds).size) throw invalid('shiftIds: errors.form.required');
    }
    const next = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.schoolModePolicy.update({
        where: { id: before.id },
        data: {
          ...(patch.blockedCategories && { blockedCategories: patch.blockedCategories }),
          ...(patch.relaxDuringBreaks !== undefined && { relaxDuringBreaks: patch.relaxDuringBreaks }),
          ...(patch.enabled !== undefined && { enabled: patch.enabled }),
          ...(patch.shiftIds && { shiftIds: [...new Set(patch.shiftIds)] }),
        },
      });
      await this.audit.write(
        actor,
        {
          module: 'SCHOOL_MODE',
          action: 'policy.update',
          summary: `Cheklov siyosati yangilandi: ${updated.name}`,
          entityId: updated.id,
          before: toPolicyView(before),
          after: toPolicyView(updated),
          params: { name: updated.name },
        },
        tx,
      );
      return updated;
    });
    void this.sync.resync(actor.schoolId);
    return toPolicyView(next);
  }

  async addAllowedApp(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'schoolMode.manage');
    const data = parseOrThrow(allowedAppSchema, input);
    const policy = await this.store.policy(actor.schoolId);
    const apps = allowedAppsOf(policy);
    if (apps.some((a) => a.name.toLowerCase() === data.name.toLowerCase())) throw conflict(`name: ${smMsg.appExists}`);
    if (apps.length >= MAX_ALLOWED_APPS) throw invalid('name: errors.form.tooLong');
    const app = { id: randomUUID(), ...data };
    const next = await this.savePolicyApps(actor, policy.id, [...apps, app], {
      action: 'policy.appAdd',
      summary: `Ruxsat etilgan ilova qo'shildi: ${app.name}`,
      entityId: app.id,
      after: app,
      params: { name: app.name },
    });
    return toPolicyView(next);
  }

  async removeAllowedApp(actor: SchoolActor, appId: string) {
    assertCan(actor, 'schoolMode.manage');
    const policy = await this.store.policy(actor.schoolId);
    const apps = allowedAppsOf(policy);
    const app = apps.find((a) => a.id === appId);
    if (!app) throw notFound(appId);
    const next = await this.savePolicyApps(
      actor,
      policy.id,
      apps.filter((a) => a.id !== appId),
      {
        action: 'policy.appRemove',
        summary: `Ruxsat etilgan ilova olib tashlandi: ${app.name}`,
        entityId: appId,
        before: app,
        params: { name: app.name },
      },
    );
    return toPolicyView(next);
  }

  /** Hafta kunlari va davrlar (raqamlar, smena boshi / oxiri qayta hisoblanadi). */
  async updateShift(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'schoolMode.manage');
    const data = parseOrThrow(shiftUpdateSchema, input);
    const updated = await this.prisma.$transaction(async (tx) => {
      const before = await tx.schoolShift.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!before) throw notFound(id);
      const periods = numberPeriods(data.periods);
      const weekdays = [...new Set(data.weekdays)].sort((a, b) => a - b);
      const start = periods[0]?.start ?? before.start;
      const end = periods.at(-1)?.end ?? before.end;
      const next = await tx.schoolShift.update({
        where: { id },
        data: { weekdays, periods: periods as unknown as Prisma.InputJsonValue, start, end },
      });
      const lessons = periods.filter((p) => p.kind === 'LESSON').length;
      await this.audit.write(
        actor,
        {
          module: 'SCHOOL_MODE',
          action: 'shift.update',
          summary: `${next.name}: qo'ng'iroq jadvali yangilandi (${lessons} dars, ${start}–${end})`,
          entityId: id,
          before: toShiftLike(before),
          after: toShiftLike(next),
          params: { name: next.name, lessons, start, end },
        },
        tx,
      );
      return next;
    });
    void this.sync.resync(actor.schoolId);
    return toShiftLike(updated);
  }

  /**
   * Ruxsati yo'q (NO_PERMISSION) qurilmalar ota-onalariga push-eslatma.
   * Parvoz Parents'ga ulangan ota-onasi bo'lmagan o'quvchi — o'tkazib yuboriladi.
   */
  async remindParents(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'schoolMode.view');
    const ids = [...new Set(parseOrThrow(remindInputSchema, input))];
    const [school, students] = await Promise.all([
      this.prisma.school.findUniqueOrThrow({ where: { id: actor.schoolId }, select: { shortName: true, name: true } }),
      this.prisma.schoolStudent.findMany({
        where: { schoolId: actor.schoolId, archived: false, id: { in: ids } },
        select: {
          id: true, firstName: true, classId: true, device: true,
          child: { select: deviceChildSelect },
          guardians: { select: { guardian: { select: { userId: true, linkStatus: true } } } },
        },
      }),
    ]);
    for (const s of students) assertClassInScope(actor, s.classId);
    const now = new Date();
    const notified: string[] = [];
    for (const s of students) {
      if (deviceStateOf(s, s.child, now).status !== 'NO_PERMISSION') continue;
      const users = [...new Set(s.guardians.flatMap(({ guardian: g }) => (g.linkStatus === 'LINKED' && g.userId ? [g.userId] : [])))];
      if (users.length === 0) continue;
      for (const userId of users) {
        const text = remindText(s.child ? 'permission' : 'link', await this.fcm.getUserLang(userId), {
          school: school.shortName || school.name,
          name: s.firstName,
        });
        await this.fcm.sendPushToUser(userId, { ...text, data: { type: 'SCHOOL_MODE_REMIND', studentId: s.id } });
      }
      notified.push(s.id);
    }
    if (notified.length > 0) {
      await this.audit.write(actor, {
        module: 'SCHOOL_MODE',
        action: 'device.remind',
        summary: `Ota-onalarga School Mode ruxsati eslatmasi yuborildi: ${notified.length} o'quvchi`,
        after: { studentIds: notified },
        params: { count: notified.length },
      });
    }
    return { sent: notified.length, skipped: ids.length - notified.length };
  }

  private async savePolicyApps(
    actor: SchoolActor,
    policyId: string,
    apps: Array<{ id: string; name: string; category: string }>,
    entry: { action: string; summary: string; entityId: string; before?: unknown; after?: unknown; params: Record<string, string> },
  ) {
    const next = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.schoolModePolicy.update({ where: { id: policyId }, data: { allowedApps: apps } });
      await this.audit.write(actor, { module: 'SCHOOL_MODE', ...entry }, tx);
      return updated;
    });
    void this.sync.resync(actor.schoolId);
    return next;
  }
}
