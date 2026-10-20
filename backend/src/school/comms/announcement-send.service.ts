// E'lonni yuborish (panel `announcements.send` / `sendNow`): darhol — vasiylarga
// yetkazish yozuvlari + haqiqiy push; `scheduledAt` bilan — SCHEDULED (vaqti
// kelganda `CommsDispatcherService` yuboradi). Javob — haqiqiy statistika bilan.

import { Injectable } from '@nestjs/common';
import { Prisma, SchoolAnnouncement } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { SchoolActor } from '../auth/school-actor';
import { SchoolAuditService } from '../common/school-audit.service';
import { conflict, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import { AnnouncementDeliveryService } from './announcement-delivery.service';
import { contentData, findEditable, parseSchedule, updateUnsent } from './announcement-editable';
import { AnnouncementView, toAnnouncementView, withStats } from './announcement-views';
import { AnnouncementInput, announcementInputSchema } from './comms.schemas';
import { assertAnySend, assertAudienceAllowed, audienceGuardians, loadRoster, reachOf, Roster, toAudience } from './comms-roster';
import { localStamp } from './comms-time';

type Tx = Prisma.TransactionClient;

@Injectable()
export class AnnouncementSendService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: SchoolAuditService,
    private readonly delivery: AnnouncementDeliveryService,
  ) {}

  /** Darhol yuborish yoki `scheduledAt` bo'yicha rejalashtirish (`id` — mavjud qoralama / rejalashtirilgan). */
  async send(actor: SchoolActor, body: unknown, id?: string): Promise<AnnouncementView> {
    assertAnySend(actor);
    const data = parseOrThrow(announcementInputSchema, body);
    const now = new Date();
    const scheduledAt = parseSchedule(body, now);
    const result = await this.prisma.$transaction(async (tx) => {
      const roster = await loadRoster(tx, actor.schoolId);
      assertAudienceAllowed(actor, roster, data.audience);
      const found = id ? await findEditable(tx, actor, roster, id) : null;
      const base = found ?? (await this.createDraft(tx, actor, data));
      return scheduledAt
        ? this.schedule(tx, actor, roster, { found, base, data, scheduledAt })
        : this.sendIn(tx, actor, roster, { found, base, data, now });
    });
    if (result.status === 'SENT') await this.delivery.pushPending(result.id, now);
    return this.view(result.id);
  }

  /** Qoralama yoki rejalashtirilgan xabarni hozir yuborish. */
  async sendNow(actor: SchoolActor, id: string): Promise<AnnouncementView> {
    assertAnySend(actor);
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      const roster = await loadRoster(tx, actor.schoolId);
      const current = await findEditable(tx, actor, roster, id);
      return this.sendIn(tx, actor, roster, { found: current, base: current, now });
    });
    await this.delivery.pushPending(id, now);
    return this.view(id);
  }

  private createDraft(tx: Tx, actor: SchoolActor, data: AnnouncementInput): Promise<SchoolAnnouncement> {
    return tx.schoolAnnouncement.create({
      data: { schoolId: actor.schoolId, byStaffId: actor.staffId, ...contentData(data), status: 'DRAFT' },
    });
  }

  private async schedule(
    tx: Tx,
    actor: SchoolActor,
    roster: Roster,
    p: { found: SchoolAnnouncement | null; base: SchoolAnnouncement; data: AnnouncementInput; scheduledAt: Date },
  ): Promise<SchoolAnnouncement> {
    const next = await updateUnsent(tx, p.base.id, actor.schoolId, {
      ...contentData(p.data),
      status: 'SCHEDULED',
      scheduledAt: p.scheduledAt,
      sentAt: null,
      recipients: reachOf(roster, p.data.audience).guardians,
    });
    const at = localStamp(p.scheduledAt);
    await this.audit.write(
      actor,
      {
        module: 'MESSAGES',
        action: 'announcement.schedule',
        summary: `"${next.title}" xabari ${at} ga rejalashtirildi`,
        entityId: next.id,
        before: p.found ? toAnnouncementView(p.found) : null,
        after: toAnnouncementView(next),
        params: { title: next.title, at },
      },
      tx,
    );
    return next;
  }

  private async sendIn(
    tx: Tx,
    actor: SchoolActor,
    roster: Roster,
    p: { found: SchoolAnnouncement | null; base: SchoolAnnouncement; data?: AnnouncementInput; now: Date },
  ): Promise<SchoolAnnouncement> {
    const audience = p.data?.audience ?? toAudience(p.base.audience);
    const sent = await this.delivery.claim(tx, {
      id: p.base.id,
      schoolId: actor.schoolId,
      from: ['DRAFT', 'SCHEDULED'],
      content: p.data && { ...p.data, audience },
      guardians: audienceGuardians(roster, audience),
      now: p.now,
    });
    if (!sent) throw conflict('already sent');
    await this.audit.write(
      actor,
      {
        module: 'MESSAGES',
        action: 'announcement.send',
        summary: `"${sent.title}" xabari yuborildi (${sent.recipients} ota-ona)`,
        entityId: sent.id,
        before: p.found ? toAnnouncementView(p.found) : null,
        after: toAnnouncementView(sent),
        params: { title: sent.title, recipients: sent.recipients },
      },
      tx,
    );
    return sent;
  }

  private async view(id: string): Promise<AnnouncementView> {
    const stored = await this.prisma.schoolAnnouncement.findUnique({ where: { id } });
    if (!stored) throw notFound(id);
    const [view] = await withStats(this.prisma, [toAnnouncementView(stored)]);
    return view!;
  }
}
