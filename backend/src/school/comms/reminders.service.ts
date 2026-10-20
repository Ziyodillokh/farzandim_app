// Smart Reminder (panel `commsService.reminders`): ro'yxat (kelgusi / o'tgan,
// butun ro'yxat bo'yicha ko'rsatkichlar), yaratish, tahrirlash, o'chirish,
// yoqish / to'xtatish. Vaqti kelganini `CommsDispatcherService` yuboradi.
// Ruxsat: reminders.manage.

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolReminder } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { matchesSearch } from '../common/list-query';
import { SchoolAuditService } from '../common/school-audit.service';
import { invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { reminderActiveSchema, reminderFilterSchema, reminderInputSchema } from './comms.schemas';
import { pageOf } from './comms-paging';
import { assertAudienceAllowed, loadRoster } from './comms-roster';
import { parseLocalDateTime } from './comms-time';
import { reminderRows, toReminderView } from './reminder-views';

type Tx = Prisma.TransactionClient;

@Injectable()
export class RemindersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async list(actor: SchoolActor, raw: Record<string, unknown>) {
    assertCan(actor, 'reminders.manage');
    const filter = parseOrThrow(reminderFilterSchema, raw);
    const roster = await loadRoster(this.prisma, actor.schoolId);
    const all = await this.prisma.schoolReminder.findMany({ where: { schoolId: actor.schoolId } });
    const rows = reminderRows(roster, all, new Date());
    const upcoming = rows.filter((r) => !r.isPast);
    const counts = { UPCOMING: upcoming.length, PAST: rows.length - upcoming.length };
    const stats = {
      upcoming: upcoming.length,
      repeating: rows.filter((r) => r.repeat !== 'NONE').length,
      paused: upcoming.filter((r) => !r.active).length,
      nextAt: upcoming.find((r) => r.active)?.nextAt ?? null,
    };
    const filtered = rows.filter(
      (r) =>
        (!filter.when || (filter.when === 'PAST') === r.isPast) &&
        (!filter.kind || r.kind === filter.kind) &&
        (!filter.search || matchesSearch(`${r.title} ${r.body} ${r.audienceNames.join(' ')}`, filter.search)),
    );
    return { ...pageOf(filtered, filter.page, filter.limit), counts, stats };
  }

  async create(actor: SchoolActor, input: unknown) {
    assertCan(actor, 'reminders.manage');
    return this.prisma.$transaction(async (tx) => {
      const data = await this.parseInput(tx, actor, input);
      assertFuture(data.sendAt);
      const created = await tx.schoolReminder.create({
        data: { schoolId: actor.schoolId, byStaffId: actor.staffId, ...data },
      });
      const view = toReminderView(created);
      await this.audit.write(
        actor,
        {
          module: 'REMINDERS',
          action: 'reminder.create',
          summary: `"${view.title}" eslatmasi yaratildi`,
          entityId: view.id,
          after: view,
          params: { title: view.title },
        },
        tx,
      );
      return view;
    });
  }

  async update(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'reminders.manage');
    return this.prisma.$transaction(async (tx) => {
      const current = await this.find(tx, actor, id);
      const data = await this.parseInput(tx, actor, input);
      if (!sameMinute(data.sendAt, current.sendAt)) assertFuture(data.sendAt);
      const next = await tx.schoolReminder.update({ where: { id }, data });
      const view = toReminderView(next);
      await this.audit.write(
        actor,
        {
          module: 'REMINDERS',
          action: 'reminder.update',
          summary: `"${view.title}" eslatmasi tahrirlandi`,
          entityId: id,
          before: toReminderView(current),
          after: view,
          params: { title: view.title },
        },
        tx,
      );
      return view;
    });
  }

  async remove(actor: SchoolActor, id: string): Promise<void> {
    assertCan(actor, 'reminders.manage');
    await this.prisma.$transaction(async (tx) => {
      const current = await this.find(tx, actor, id);
      await tx.schoolReminder.delete({ where: { id } });
      await this.audit.write(
        actor,
        {
          module: 'REMINDERS',
          action: 'reminder.delete',
          summary: `"${current.title}" eslatmasi o'chirildi`,
          entityId: id,
          before: toReminderView(current),
          params: { title: current.title },
        },
        tx,
      );
    });
  }

  async setActive(actor: SchoolActor, id: string, input: unknown) {
    assertCan(actor, 'reminders.manage');
    const { active } = parseOrThrow(reminderActiveSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const current = await this.find(tx, actor, id);
      const next = await tx.schoolReminder.update({ where: { id }, data: { active } });
      await this.audit.write(
        actor,
        {
          module: 'REMINDERS',
          action: 'reminder.toggle',
          summary: `"${next.title}" eslatmasi ${active ? 'yoqildi' : "to'xtatildi"}`,
          entityId: id,
          before: { active: current.active },
          after: { active },
          params: { variant: active ? 'on' : 'off', title: next.title },
        },
        tx,
      );
      return toReminderView(next);
    });
  }

  private async find(tx: Tx, actor: SchoolActor, id: string): Promise<SchoolReminder> {
    const found = await tx.schoolReminder.findFirst({ where: { id, schoolId: actor.schoolId } });
    if (!found) throw notFound(id);
    return found;
  }

  /** Forma → baza maydonlari (auditoriya mavjudligi va doirasi tekshiriladi). */
  private async parseInput(tx: Tx, actor: SchoolActor, input: unknown) {
    const data = parseOrThrow(reminderInputSchema, input);
    const roster = await loadRoster(tx, actor.schoolId);
    assertAudienceAllowed(actor, roster, data.audience);
    return {
      kind: data.kind,
      title: data.title,
      body: data.body,
      audience: data.audience as unknown as Prisma.InputJsonValue,
      sendAt: toInstant(data.sendAt),
      repeat: data.repeat,
      active: data.active,
    };
  }
}

function toInstant(sendAt: string): Date {
  const at = parseLocalDateTime(sendAt);
  if (!at) throw invalid('sendAt: errors.form.invalidDate');
  return at;
}

/** Panel forma vaqtni daqiqagacha qaytaradi ("…T09:00") — o'zgarish shu aniqlikda. */
function sameMinute(a: Date, b: Date): boolean {
  return Math.floor(a.getTime() / 60_000) === Math.floor(b.getTime() / 60_000);
}

function assertFuture(sendAt: Date): void {
  if (!(sendAt.getTime() > Date.now())) throw invalid('sendAt: errors.form.invalidDate');
}
