// Kun davomida qayta chiqish va kirish (karta bilan): bola ko'chaga chiqsa — kartani tegizib chiqadi, qaytganda
// tegizib kiradi; bir kunda necha marta bo'lsa ham. Kunlik yozuvdagi `outAt` — hozir tashqaridami (chiqishda
// qo'yiladi, qaytishda tozalanadi); har harakat `SchoolAttendanceEvent` ga yoziladi. Ota-onalarga har harakatda push
// (kunlik «bir marta» cheklovisiz — har harakat bitta tegishdan bir marta keladi). Dars vaqtida bo'lsa — maktab
// xodimlariga (direktor, navbatchi, sinf rahbari) bildirishnoma. Kunning birinchi yakuniy chiqishi esa avvalgidek
// `AttendanceArrivalService.depart` (LEFT xabari, qayta yuborish bilan).

import { Injectable } from '@nestjs/common';
import { AttendanceSource } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { SchoolModeSyncService } from '../school-mode/school-mode-sync.service';
import { AttendanceNotifyService } from './attendance-notify.service';
import { minutesToHhmm, tashkentMinute } from './attendance-time';

export type MovementDirection = 'OUT' | 'IN';

/** Xodim lentasi: dars vaqtida maktabdan chiqdi / qaytdi. */
export const STEPPED_OUT_KIND = 'STUDENT_STEPPED_OUT';
export const RETURNED_KIND = 'STUDENT_RETURNED';
const MOVEMENT_ROLES = ['ADMIN', 'DIRECTOR', 'DUTY', 'HOMEROOM'];

export interface MovementContext {
  schoolId: string;
  studentId: string;
  classId: string | null;
  source: Extract<AttendanceSource, 'CARD'>;
  now: Date;
  /** Smena hali tugamagan (dars vaqti): xodimlar xabardor qilinadi, chiqish «ko'chaga chiqdi» deb yuboriladi. */
  duringShift: boolean;
  /** Xodim bildirishnomasi uchun: o'quvchi ismi va sinf nomi. */
  studentName: string;
  className: string;
}

@Injectable()
export class AttendanceMovementService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notify: AttendanceNotifyService,
    private readonly schoolMode: SchoolModeSyncService,
  ) {}

  /** Chiqish (ichkarida bo'lsa) yoki qaytish (tashqarida bo'lsa). Holat mos kelmasa — `false`, hech narsa yozilmaydi. */
  async move(ctx: MovementContext, recordId: string, direction: MovementDirection): Promise<boolean> {
    const time = minutesToHhmm(Math.floor(tashkentMinute(ctx.now)));
    const date = await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.schoolAttendance.updateMany({
        where: direction === 'OUT' ? { id: recordId, outAt: null, inAt: { not: null } } : { id: recordId, outAt: { not: null } },
        data: { outAt: direction === 'OUT' ? time : null },
      });
      if (count === 0) return null;
      const record = await tx.schoolAttendance.findUniqueOrThrow({ where: { id: recordId }, select: { date: true } });
      await tx.schoolAttendanceEvent.create({
        data: { schoolId: ctx.schoolId, at: ctx.now, date: record.date, studentId: ctx.studentId, classId: ctx.classId, kind: direction, source: ctx.source },
      });
      if (ctx.duringShift) {
        await tx.schoolStaffNotification.create({
          data: {
            schoolId: ctx.schoolId,
            kind: direction === 'OUT' ? STEPPED_OUT_KIND : RETURNED_KIND,
            at: ctx.now,
            roles: MOVEMENT_ROLES,
            classIds: ctx.classId ? [ctx.classId] : [],
            params: { studentName: ctx.studentName, className: ctx.className, time },
          },
        });
      }
      return record.date;
    });
    if (date === null) return false;
    await this.notify.notifyMovement({
      studentId: ctx.studentId,
      date,
      time,
      push: direction === 'IN' ? 'returned' : ctx.duringShift ? 'steppedOut' : 'left',
    });
    await this.schoolMode.refreshStudent(ctx.studentId);
    return true;
  }
}
