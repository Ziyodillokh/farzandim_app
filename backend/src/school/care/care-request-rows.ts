// Psixolog paneli `CareRequestRow`: shifr ochiladi, ism / sinf, o'qilmagan xabarlar va
// mas'ul xodim qo'shiladi. Tafsilotdagi yozishma ham shu yerda quriladi.

import { Injectable } from '@nestjs/common';
import { SchoolCareRequest } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { threadOf } from './care-thread';

export interface StaffRef {
  id: string;
  name: string;
}

@Injectable()
export class CareRequestRows {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
  ) {}

  async rows(schoolId: string, requests: SchoolCareRequest[]) {
    const ids = requests.map((r) => r.id);
    const [students, classes, unread, staff] = await Promise.all([
      this.prisma.schoolStudent.findMany({ where: { schoolId, id: { in: requests.map((r) => r.studentId) } }, select: { id: true, lastName: true, firstName: true } }),
      this.prisma.schoolClass.findMany({ where: { schoolId }, select: { id: true, name: true } }),
      this.prisma.schoolCareMessage.groupBy({ by: ['requestId'], where: { requestId: { in: ids }, author: 'CHILD', readByStaffAt: null }, _count: { _all: true } }),
      this.staffNames(schoolId, requests.flatMap((r) => [r.assignedStaffId, r.openedByStaffId])),
    ]);
    const studentName = new Map(students.map((s) => [s.id, `${s.lastName} ${s.firstName}`]));
    const className = new Map(classes.map((c) => [c.id, c.name]));
    const unreadOf = new Map(unread.map((u) => [u.requestId, u._count._all]));
    const ref = (id: string | null): StaffRef | null => (id && staff.has(id) ? { id, name: staff.get(id)! } : null);
    return requests.map((r) => ({
      raw: r,
      openedBy: ref(r.openedByStaffId),
      view: {
        id: r.id,
        studentId: r.studentId,
        classId: r.classId ?? '',
        createdAt: r.createdAt.toISOString(),
        topic: r.topic,
        message: this.crypto.decrypt(r.messageEnc),
        urgency: r.urgency,
        status: r.status,
        meetingAt: r.meetingAt?.toISOString() ?? null,
        protocolActivated: r.protocolActivated,
        studentName: studentName.get(r.studentId) ?? '—',
        className: (r.classId && className.get(r.classId)) || '—',
        openedAt: r.openedAt?.toISOString() ?? null,
        repliedAt: r.repliedAt?.toISOString() ?? null,
        unreadFromChild: unreadOf.get(r.id) ?? 0,
        assignedTo: ref(r.assignedStaffId),
        escalatedAt: r.escalatedAt?.toISOString() ?? null,
      },
    }));
  }

  /** Yozishma (xodim tomoni: xodim xabarlarida F.I.Sh.). */
  async thread(schoolId: string, request: SchoolCareRequest) {
    const rows = await this.prisma.schoolCareMessage.findMany({ where: { requestId: request.id } });
    const names = await this.staffNames(schoolId, rows.map((m) => m.staffId));
    return threadOf(request, rows, { decrypt: (t) => this.crypto.decrypt(t), nameOf: (id) => (id ? (names.get(id) ?? null) : null) });
  }

  /** Xodim id → F.I.Sh. (shu maktab doirasida; noma'lum id yo'q). */
  async staffNames(schoolId: string, ids: ReadonlyArray<string | null>): Promise<Map<string, string>> {
    const wanted = [...new Set(ids.filter((id): id is string => id !== null))];
    if (wanted.length === 0) return new Map();
    const staff = await this.prisma.schoolStaff.findMany({ where: { schoolId, id: { in: wanted } }, select: { id: true, fullName: true } });
    return new Map(staff.map((s) => [s.id, s.fullName]));
  }
}
