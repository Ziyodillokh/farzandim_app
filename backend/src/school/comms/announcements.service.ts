// E'lonlar (panel `commsService.announcements`): ro'yxat, tafsilot, qoralama,
// o'chirish, nusxa. Yuborish / rejalashtirish — `AnnouncementSendService`.
// Ruxsatlar: messages.view; yozish — messages.sendSchool | messages.sendClass.

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { allowedClassIds, assertCan, SchoolActor } from '../auth/school-actor';
import { matchesSearch } from '../common/list-query';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, forbidden, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { contentData, findEditable, updateUnsent } from './announcement-editable';
import {
  isVisible,
  loadAnnouncementContext,
  toAnnouncementView,
  toRow,
  visibleRows,
  withStats,
} from './announcement-views';
import { announcementFilterSchema, announcementInputSchema, Audience, MESSAGE_STATUSES } from './comms.schemas';
import { countBy, pageOf } from './comms-paging';
import { assertAnySend, assertAudienceAllowed, canSendTo, loadRoster, reachOf, toAudience } from './comms-roster';

@Injectable()
export class AnnouncementsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
  ) {}

  async list(actor: SchoolActor, raw: Record<string, unknown>) {
    assertCan(actor, 'messages.view');
    const filter = parseOrThrow(announcementFilterSchema, raw);
    const ctx = await loadAnnouncementContext(this.prisma, actor.schoolId);
    const rows = await visibleRows(this.prisma, actor, ctx);
    const counts = countBy(rows, MESSAGE_STATUSES, (r) => r.status);
    const filtered = rows.filter(
      (r) =>
        (!filter.status || r.status === filter.status) &&
        (!filter.search || matchesSearch(`${r.title} ${r.body} ${r.audienceNames.join(' ')}`, filter.search)),
    );
    const page = pageOf(filtered, filter.page, filter.limit);
    return { ...page, items: await withStats(this.prisma, page.items), counts };
  }

  /** Tafsilot: qator + hozirgi auditoriya hajmi + haqiqiy yetkazish natijalari. */
  async get(actor: SchoolActor, id: string) {
    assertCan(actor, 'messages.view');
    const stored = await this.prisma.schoolAnnouncement.findFirst({ where: { id, schoolId: actor.schoolId } });
    if (!stored) throw notFound(id);
    const ctx = await loadAnnouncementContext(this.prisma, actor.schoolId);
    const view = toAnnouncementView(stored);
    if (!isVisible(actor, ctx.roster, view)) throw forbidden(id);
    const [row] = await withStats(this.prisma, [toRow(actor, ctx, view)]);
    return { ...row!, reach: reachOf(ctx.roster, view.audience), delivery: await this.delivery(id, row!.stats.delivered) };
  }

  /** Qoralama: yangi yoki mavjud (qoralama / rejalashtirilgan) xabarni qoralamaga qaytarish. */
  async saveDraft(actor: SchoolActor, input: unknown, id?: string) {
    assertAnySend(actor);
    const data = parseOrThrow(announcementInputSchema, input);
    return this.prisma.$transaction(async (tx) => {
      const roster = await loadRoster(tx, actor.schoolId);
      assertAudienceAllowed(actor, roster, data.audience);
      const found = id ? await findEditable(tx, actor, roster, id) : null;
      const fields = {
        ...contentData(data),
        status: 'DRAFT' as const,
        scheduledAt: null,
        sentAt: null,
        recipients: reachOf(roster, data.audience).guardians,
      };
      const next = found
        ? await updateUnsent(tx, found.id, actor.schoolId, fields)
        : await tx.schoolAnnouncement.create({ data: { schoolId: actor.schoolId, byStaffId: actor.staffId, ...fields } });
      await this.audit.write(
        actor,
        {
          module: 'MESSAGES',
          action: found ? 'announcement.update' : 'announcement.draft',
          summary: `"${next.title}" qoralama sifatida saqlandi`,
          entityId: next.id,
          before: found ? toAnnouncementView(found) : null,
          after: toAnnouncementView(next),
          params: { title: next.title },
        },
        tx,
      );
      return toAnnouncementView(next);
    });
  }

  /** Qoralama yoki rejalashtirilgan (hali yuborilmagan) xabarni o'chirish. */
  async remove(actor: SchoolActor, id: string): Promise<void> {
    assertAnySend(actor);
    await this.prisma.$transaction(async (tx) => {
      const roster = await loadRoster(tx, actor.schoolId);
      const current = await findEditable(tx, actor, roster, id);
      const res = await tx.schoolAnnouncement.deleteMany({
        where: { id, schoolId: actor.schoolId, status: { not: 'SENT' } },
      });
      if (res.count !== 1) throw conflict('already sent');
      const draft = current.status === 'DRAFT';
      await this.audit.write(
        actor,
        {
          module: 'MESSAGES',
          action: 'announcement.delete',
          summary: `"${current.title}" ${draft ? 'qoralamasi' : 'rejalashtirilgan xabari'} o'chirildi`,
          entityId: id,
          before: toAnnouncementView(current),
          params: { variant: draft ? 'draft' : 'scheduled', title: current.title },
        },
        tx,
      );
    });
  }

  /** Nusxa — yangi qoralama. Sinf rahbari maktab xabarini nusxalasa, auditoriya o'z sinfiga o'tadi. */
  async duplicate(actor: SchoolActor, id: string) {
    assertAnySend(actor);
    return this.prisma.$transaction(async (tx) => {
      const roster = await loadRoster(tx, actor.schoolId);
      const source = await tx.schoolAnnouncement.findFirst({ where: { id, schoolId: actor.schoolId } });
      if (!source || !isVisible(actor, roster, toAnnouncementView(source))) throw notFound(id);
      const own = allowedClassIds(actor);
      const sourceAudience = toAudience(source.audience);
      const audience: Audience | null = canSendTo(actor, roster, sourceAudience)
        ? sourceAudience
        : own?.length
          ? { kind: 'CLASSES', classIds: [...own], guardianIds: [] }
          : null;
      if (!audience) throw forbidden(id);
      const copy = await tx.schoolAnnouncement.create({
        data: {
          schoolId: actor.schoolId,
          byStaffId: actor.staffId,
          ...contentData({ title: source.title, body: source.body, priority: source.priority === 'IMPORTANT' ? 'IMPORTANT' : 'NORMAL', audience }),
          status: 'DRAFT',
          recipients: reachOf(roster, audience).guardians,
        },
      });
      await this.audit.write(
        actor,
        {
          module: 'MESSAGES',
          action: 'announcement.duplicate',
          summary: `"${source.title}" xabaridan nusxa olindi`,
          entityId: copy.id,
          after: toAnnouncementView(copy),
          params: { title: source.title },
        },
        tx,
      );
      return toAnnouncementView(copy);
    });
  }

  /** Yetkazish natijalari: yetkazildi / ilovasiz vasiy / push o'tmadi (qurilma yo'q yoki xato). */
  private async delivery(announcementId: string, delivered: number) {
    const pending = { announcementId, deliveredAt: null };
    const noApp = await this.prisma.schoolAnnouncementDelivery.count({ where: { ...pending, userId: null } });
    const failed = await this.prisma.schoolAnnouncementDelivery.count({ where: { ...pending, userId: { not: null } } });
    return { delivered, noApp, failed };
  }
}
