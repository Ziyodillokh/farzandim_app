// Har o'zgarish — maktab audit jurnaliga (kim, nima, qachon, oldin / keyin).
// Tranzaksiya ichida ham chaqiriladi: o'zgarish va yozuv birga saqlanadi.

import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { SchoolActor } from '../auth/school-actor';

export type AuditModule =
  | 'AUTH'
  | 'SCHOOL'
  | 'CLASSES'
  | 'STUDENTS'
  | 'GUARDIANS'
  | 'STAFF'
  | 'ATTENDANCE'
  | 'SCHOOL_MODE'
  | 'MESSAGES'
  | 'REMINDERS'
  | 'PAYMENTS'
  | 'CARE'
  | 'LEARNING'
  | 'ASSESSMENTS'
  | 'SETTINGS';

export interface AuditEntry {
  module: AuditModule;
  action: string;
  summary: string;
  entityId?: string | null;
  before?: unknown;
  after?: unknown;
  /** Tarjima parametrlari (`audit.actions.<action>`). */
  params?: Record<string, string | number>;
}

type Db = Prisma.TransactionClient | PrismaService;

const json = (value: unknown) =>
  value === undefined || value === null
    ? Prisma.JsonNull
    : (JSON.parse(JSON.stringify(value)) as Prisma.InputJsonValue);

@Injectable()
export class SchoolAuditService {
  constructor(private readonly prisma: PrismaService) {}

  async write(actor: SchoolActor, entry: AuditEntry, db: Db = this.prisma): Promise<void> {
    await this.create(db, { schoolId: actor.schoolId, actorId: actor.staffId, actorName: actor.name, ip: actor.ip }, entry);
  }

  /**
   * Xodim bo'lmagan manba (ota-ona ilovasi, tizim / cron) yozuvi — `actorId` yo'q,
   * `actorName` jurnalda ko'rinadi ("Ota-ona: …", "Tizim").
   */
  async writeExternal(schoolId: string, actorName: string, entry: AuditEntry, db: Db = this.prisma): Promise<void> {
    await this.create(db, { schoolId, actorId: null, actorName }, entry);
  }

  private async create(
    db: Db,
    who: { schoolId: string; actorId: string | null; actorName: string; ip?: string },
    entry: AuditEntry,
  ): Promise<void> {
    await db.schoolAuditLog.create({
      data: {
        schoolId: who.schoolId,
        actorId: who.actorId,
        actorName: who.actorName,
        module: entry.module,
        action: entry.action,
        entityId: entry.entityId ?? null,
        summary: entry.summary,
        params: entry.params ? (entry.params as Prisma.InputJsonValue) : Prisma.JsonNull,
        before: json(entry.before),
        after: json(entry.after),
        ip: who.ip ?? null,
      },
    });
  }
}
