// Kiosk karta tegishi (`attendance.kiosk`): kartani aniqlash va tekshirish (NTAG 424 DNA
// kodi, hisoblagich — nusxa / qayta yuborishga qarshi), kirish yoki chiqishni qayd etish
// (QR bilan bir xil qoida), "bir o'qigichda 3 soniyada ikki karta" belgisi va jurnal.
// Natija har doim 200 + `result`: kiosk uni rang va ovoz bilan ko'rsatadi.

import { Injectable } from '@nestjs/common';
import { SchoolCardTapResult } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { tashkentDay } from '../../common/time/tashkent';
import { assertCan, SchoolActor } from '../auth/school-actor';
import { invalid } from '../common/school-errors';
import { msg, parseOrThrow } from '../common/school-zod';
import { AttendanceArrivalService } from './attendance-arrival.service';
import { QR_CLOSE_AFTER_MINUTES, QR_OPEN_BEFORE_MINUTES } from './attendance-child.service';
import { classNames } from './attendance-lookups';
import { AttendanceClock, hhmmToMinutes, isSchoolDay, minutesToHhmm, tashkentMinute } from './attendance-time';
import { CardKeyService } from './card-keys.service';
import { cardTapSchema } from './cards.schemas';

/** Bir o'qigichda shu oraliqda ikki xil karta — "shubhali". */
export const SUSPICIOUS_WINDOW_MS = 3_000;
/** Oflayn navbatdagi tegish shundan eski bo'lsa — qabul qilinmaydi. */
export const MAX_QUEUED_TAP_AGE_MS = 12 * 3_600_000;
/** Kiosk soati server soatidan shuncha oldinda bo'lishi mumkin. */
const MAX_CLOCK_SKEW_MS = 2 * 60_000;

export interface CardTapView {
  result: SchoolCardTapResult;
  time: string;
  suspicious: boolean;
  cardNumber: string | null;
  student: { id: string; firstName: string; lastName: string; studentCode: string } | null;
  className: string;
  status: string | null;
}

@Injectable()
export class CardTapService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: AttendanceClock,
    private readonly keys: CardKeyService,
    private readonly arrival: AttendanceArrivalService,
  ) {}

  async tap(actor: SchoolActor, input: unknown): Promise<CardTapView> {
    assertCan(actor, 'attendance.kiosk');
    const data = parseOrThrow(cardTapSchema, input);
    const now = this.clock.now();
    const tappedAt = this.tapTime(data.tappedAt, now);
    const kioskId = data.kioskId || actor.staffId;
    const base = { time: minutesToHhmm(Math.floor(tashkentMinute(tappedAt))), suspicious: false, cardNumber: null, student: null, className: '', status: null };

    const identity = await this.keys.identify(actor.schoolId, data);
    if (!identity) return this.log(actor, { ...base, result: 'INVALID' }, { tappedAt, kioskId });

    const card = await this.prisma.schoolCard.findUnique({
      where: { schoolId_uid: { schoolId: actor.schoolId, uid: identity.uid } },
      include: { student: { include: { class: { include: { shift: true } }, school: { select: { lateAfterMinutes: true } } } } },
    });
    const meta = { tappedAt, kioskId, uid: identity.uid };
    if (!card) return this.log(actor, { ...base, result: 'UNKNOWN' }, meta);

    const student = card.student;
    const cls = student.class;
    const classes = await classNames(this.prisma, actor.schoolId, [student.classId]);
    const known = {
      ...base,
      cardNumber: card.number,
      student: { id: student.id, firstName: student.firstName, lastName: student.lastName, studentCode: student.studentCode },
      className: (student.classId && classes.get(student.classId)) || '',
    };
    const cardMeta = { ...meta, cardId: card.id, studentId: student.id };

    // NTAG 424 DNA kartasi imzosiz o'qilsa — nusxa (faqat UID ko'chirilgan); hisoblagich faqat oshishi kerak.
    if (card.kind === 'SUN' && identity.kind !== 'SUN') return this.log(actor, { ...known, result: 'INVALID' }, cardMeta);
    if (identity.counter !== null && !(await this.acceptCounter(card.id, identity.counter))) {
      return this.log(actor, { ...known, result: 'INVALID' }, cardMeta);
    }
    if (card.status !== 'ACTIVE' || student.archived) return this.log(actor, { ...known, result: 'BLOCKED' }, cardMeta);
    const suspicious = await this.isSuspicious(actor.schoolId, kioskId, card.id, tappedAt);
    if (!cls || !(await this.withinSchoolHours(actor.schoolId, cls.shift, tappedAt))) {
      return this.log(actor, { ...known, suspicious, result: 'OUTSIDE' }, cardMeta);
    }

    const ctx = { schoolId: actor.schoolId, studentId: student.id, classId: cls.id, source: 'CARD' as const, now: tappedAt };
    const existing = await this.prisma.schoolAttendance.findUnique({
      where: { studentId_date: { studentId: student.id, date: tashkentDay(tappedAt) } },
    });
    let result: SchoolCardTapResult = 'NONE';
    let status = existing?.status ?? null;
    if (!existing?.inAt) {
      const arrived = await this.arrival.arrive({
        ...ctx,
        shiftStart: cls.shift.start,
        lateAfterMinutes: student.school.lateAfterMinutes,
        byStaffId: actor.staffId,
      });
      result = arrived.alreadyIn ? 'NONE' : 'IN';
      status = arrived.record.status;
    } else {
      const leaving =
        !existing.outAt && (existing.status === 'PRESENT' || existing.status === 'LATE') && tashkentMinute(tappedAt) >= hhmmToMinutes(cls.shift.end);
      if (leaving && (await this.arrival.depart(ctx, existing.id))) result = 'OUT';
    }
    await this.prisma.schoolCard.update({ where: { id: card.id }, data: { lastTapAt: tappedAt } });
    return this.log(actor, { ...known, suspicious, result, status }, cardMeta);
  }

  /** Oflayn navbat vaqti: 12 soatdan eski — rad; kelajakdagi (soat farqi) — hozir. */
  private tapTime(raw: string | undefined, now: Date): Date {
    if (!raw) return now;
    const at = new Date(raw);
    if (now.getTime() - at.getTime() > MAX_QUEUED_TAP_AGE_MS) throw invalid(`tappedAt: ${msg.date}`);
    return at.getTime() > now.getTime() + MAX_CLOCK_SKEW_MS ? now : at;
  }

  /** Hisoblagich oxirgisidan katta bo'lsagina qabul (parallel tegishda ham bittasi o'tadi). */
  private async acceptCounter(cardId: string, counter: number): Promise<boolean> {
    const { count } = await this.prisma.schoolCard.updateMany({
      where: { id: cardId, OR: [{ lastCounter: null }, { lastCounter: { lt: counter } }] },
      data: { lastCounter: counter },
    });
    return count > 0;
  }

  /** Shu o'qigichda 3 soniya ichida boshqa karta tegizilganmi. */
  private async isSuspicious(schoolId: string, kioskId: string, cardId: string, tappedAt: Date): Promise<boolean> {
    const previous = await this.prisma.schoolCardTap.findFirst({
      where: {
        schoolId,
        kioskId,
        cardId: { not: null },
        tappedAt: { gte: new Date(tappedAt.getTime() - SUSPICIOUS_WINDOW_MS), lte: tappedAt },
      },
      orderBy: { tappedAt: 'desc' },
      select: { cardId: true },
    });
    return Boolean(previous && previous.cardId !== cardId);
  }

  /** QR bilan bir xil oyna: dars kuni, smena boshidan 2 soat oldin — tugaganidan 3 soat keyin. */
  private async withinSchoolHours(schoolId: string, shift: { start: string; end: string; weekdays: number[] }, at: Date): Promise<boolean> {
    const date = tashkentDay(at);
    const holiday = await this.prisma.schoolHoliday.findUnique({ where: { schoolId_date: { schoolId, date } } });
    const minute = tashkentMinute(at);
    return (
      isSchoolDay(date, shift, new Set(holiday ? [date] : [])) &&
      minute >= hhmmToMinutes(shift.start) - QR_OPEN_BEFORE_MINUTES &&
      minute <= hhmmToMinutes(shift.end) + QR_CLOSE_AFTER_MINUTES
    );
  }

  private async log(
    actor: SchoolActor,
    view: CardTapView,
    meta: { tappedAt: Date; kioskId: string; uid?: string; cardId?: string; studentId?: string },
  ): Promise<CardTapView> {
    await this.prisma.schoolCardTap.create({
      data: {
        schoolId: actor.schoolId,
        tappedAt: meta.tappedAt,
        cardId: meta.cardId ?? null,
        studentId: meta.studentId ?? null,
        uid: meta.uid ?? null,
        result: view.result,
        suspicious: view.suspicious,
        kioskId: meta.kioskId,
        staffId: actor.staffId,
      },
    });
    return view;
  }
}
