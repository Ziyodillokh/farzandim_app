import type { Id, IsoDateTime } from './common';

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

export type AuditLog = {
  id: Id;
  at: IsoDateTime;
  actorId: Id;
  actorName: string;
  module: AuditModule;
  action: string; // "student.create"
  entityId: Id | null;
  summary: string;
  /** Tarjima uchun parametrlar (`audit.actions.<action>`), bo'lmasa `summary` ko'rsatiladi. */
  params?: Record<string, string | number>;
  before: unknown;
  after: unknown;
};
