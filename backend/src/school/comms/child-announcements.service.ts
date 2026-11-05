// Parvoz Growth bola ilovasi: maktab e'lonlari (M-bo'lim). Bola faqat o'z maktabi /
// sinfiga yuborilgan VA xodim "o'quvchilarga ham" belgilagan e'lonlarni ko'radi.
// O'qildi belgisi o'quvchi bo'yicha alohida jadvalda (ota-ona o'qishi `Delivery`da).

import { Injectable } from '@nestjs/common';
import { SchoolAnnouncement } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { requireEnrolledStudent } from '../common/child-student';
import { invalid, notFound } from '../common/school-errors';
import { parseOrThrow } from '../common/school-zod';
import {
  afterCursorWhere,
  childVisibleWhere,
  ChildAnnouncementItem,
  decodeCursor,
  encodeCursor,
} from './child-announcements-view';
import { childAnnouncementsQuerySchema } from './comms.schemas';
import { toAudience } from './comms-roster';

@Injectable()
export class ChildAnnouncementsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(childUserId: string, raw: unknown) {
    const query = parseOrThrow(childAnnouncementsQuerySchema, raw ?? {});
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const cursor = query.cursor ? decodeCursor(query.cursor) : null;
    if (query.cursor && !cursor) throw invalid('cursor: invalid');
    const visible = childVisibleWhere(student.schoolId, student.classId);
    const [rows, unreadCount] = await Promise.all([
      this.prisma.schoolAnnouncement.findMany({
        where: { AND: [visible, cursor ? afterCursorWhere(cursor) : {}] },
        orderBy: [{ sentAt: 'desc' }, { id: 'desc' }],
        take: query.limit + 1,
        include: { studentReads: { where: { studentId: student.studentId }, select: { id: true } } },
      }),
      this.prisma.schoolAnnouncement.count({
        where: { AND: [visible, { studentReads: { none: { studentId: student.studentId } } }] },
      }),
    ]);
    const page = rows.slice(0, query.limit);
    const authors = await this.authors(student.schoolId, page);
    const items = page.map((a): ChildAnnouncementItem => {
      const label = toAudience(a.audience).kind === 'SCHOOL' ? 'SCHOOL' : 'CLASS';
      return {
        id: a.id,
        title: a.title,
        body: a.body,
        priority: a.priority === 'IMPORTANT' ? 'IMPORTANT' : 'NORMAL',
        sentAt: a.sentAt?.toISOString() ?? null,
        author: authors.get(a.byStaffId) ?? { name: '—', role: null },
        audienceLabel: label,
        ...(label === 'CLASS' && { className: student.className }),
        read: a.studentReads.length > 0,
      };
    });
    const last = page.at(-1);
    return { items, unreadCount, nextCursor: rows.length > query.limit && last ? encodeCursor(last) : null };
  }

  /** O'qildi (idempotent): birinchi o'qish vaqti saqlanadi. Ko'rinmaydigan e'lon — 404. */
  async markRead(childUserId: string, announcementId: string) {
    const student = await requireEnrolledStudent(this.prisma, childUserId);
    const visible = childVisibleWhere(student.schoolId, student.classId);
    const found = await this.prisma.schoolAnnouncement.findFirst({
      where: { AND: [visible, { id: announcementId }] },
      select: { id: true },
    });
    if (!found) throw notFound(announcementId);
    const key = { announcementId, studentId: student.studentId };
    await this.prisma.schoolAnnouncementStudentRead.createMany({ data: [key], skipDuplicates: true });
    const read = await this.prisma.schoolAnnouncementStudentRead.findUniqueOrThrow({
      where: { announcementId_studentId: key },
    });
    return { id: announcementId, readAt: read.readAt.toISOString() };
  }

  private async authors(schoolId: string, rows: readonly SchoolAnnouncement[]) {
    const ids = [...new Set(rows.map((r) => r.byStaffId))];
    if (ids.length === 0) return new Map<string, { name: string; role: string | null }>();
    const staff = await this.prisma.schoolStaff.findMany({
      where: { schoolId, id: { in: ids } },
      select: { id: true, fullName: true, role: true },
    });
    return new Map(staff.map((s) => [s.id, { name: s.fullName, role: s.role as string | null }]));
  }
}
