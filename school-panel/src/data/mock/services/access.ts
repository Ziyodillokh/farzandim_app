import type { ChildCredentials, CredentialsView, InviteCode, IssuedCredentials, IssueCredentialsInput, RecoveryRequest, Student } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { issueCredentialsSchema } from '@/data/schemas/access';
import { parseOrThrow } from '@/data/schemas/validate';
import {
  activeInviteOf,
  generateTemporaryPassword,
  INVITE_TTL_HOURS,
  openRecoveryOf,
  suggestLogin,
  toInviteCodeView,
  uniqueInviteCode,
} from '../access-model';
import type { MockCredential } from '../access-tables';
import { toLocalIso } from '../calendar';
import { clockNow } from '../clock';
import { type Actor, assertCan, assertClassInScope, currentActor, latency, newId, writeAudit } from '../context';
import { getTables, transact } from '../db';
import { studentName } from '../lookups';
import type { Tables } from '../tables';

/**
 * Kirish (5-bosqich) — o'quvchi kartasi: kirish ma'lumotlari, 6 xonali maktab kodi, parol tiklash so'rovlari.
 * Backend (K1/K2) bilan bir xil qoidalar:
 *  - kirish ma'lumotlari — `students.manage`, faqat bola profiliga ulangan o'quvchiga (aks holda `CONFLICT`/`NOT_LINKED`);
 *  - kod — `guardians.link`; sinf rahbari faqat o'z sinfida;
 *  - vaqtinchalik parol FAQAT natijada qaytadi: bazaga, auditga va logga yozilmaydi.
 */

const HOUR_MS = 3_600_000;

function studentInScope(t: Tables, actor: Actor, studentId: string): Student {
  const student = t.students.find((s) => s.id === studentId);
  if (!student) throw new ServiceError('NOT_FOUND', studentId);
  assertClassInScope(actor, student.classId);
  return student;
}

function publicCredentials(record: MockCredential): ChildCredentials {
  return {
    login: record.login,
    issuedBy: record.issuedBy,
    issuedAt: record.issuedAt,
    mustChangePassword: record.mustChangePassword,
    lastLoginAt: record.lastLoginAt,
  };
}

const notLinked = () => new ServiceError('CONFLICT', 'NOT_LINKED', 'NOT_LINKED');
const loginTaken = () => new ServiceError('CONFLICT', 'LOGIN_TAKEN', 'LOGIN_TAKEN');

export const accessService = {
  /** Kirish ma'lumotlari holati. `linked: false` — o'quvchi hali bola profiliga ulanmagan. */
  async credentials(studentId: string): Promise<CredentialsView> {
    await latency(60, 140);
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const t = getTables();
    const student = studentInScope(t, actor, studentId);
    if (!t.access.linkedStudentIds.includes(student.id)) return { linked: false, credentials: null };
    const record = t.access.credentials.find((c) => c.studentId === student.id);
    return { linked: true, credentials: record ? publicCredentials(record) : null };
  },

  /**
   * Birinchi berish yoki tiklash (mavjud bo'lsa). Yangi vaqtinchalik parol FAQAT natijada qaytadi.
   * Tiklash: boshqa qurilmalardan chiqarish (standart yoqilgan), shu o'quvchining ochiq tiklash so'rovlari hal qilinadi.
   */
  async issueCredentials(studentId: string, input: IssueCredentialsInput = {}): Promise<IssuedCredentials> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const data = parseOrThrow(issueCredentialsSchema, input);
    return transact((t) => {
      const student = studentInScope(t, actor, studentId);
      if (!t.access.linkedStudentIds.includes(student.id)) throw notLinked();
      const now = toLocalIso(clockNow());
      const temporaryPassword = generateTemporaryPassword();
      const existing = t.access.credentials.find((c) => c.studentId === student.id);
      const name = studentName(student);

      if (existing) {
        const signOut = data.signOutDevices ?? true;
        existing.issuedBy = 'SCHOOL';
        existing.issuedAt = now;
        existing.mustChangePassword = true;
        for (const r of t.access.recoveryRequests) {
          if (r.studentId !== student.id || r.status !== 'RECEIVED') continue;
          r.status = 'RESTORED';
          r.resolvedAt = now;
        }
        writeAudit(t, actor, 'STUDENTS', 'student.credentials.reset', `${name}: kirish paroli tiklandi`, student.id, null, null, {
          name,
          ...(signOut ? { variant: 'signOut' } : {}),
        });
        return { login: existing.login, temporaryPassword, issuedAt: now };
      }

      const taken = new Set(t.access.credentials.map((c) => c.login));
      if (data.login && taken.has(data.login)) throw loginTaken();
      const login = data.login ?? suggestLogin(student, taken, `${student.id}|${t.access.credentials.length}`);
      t.access.credentials.push({ studentId: student.id, login, issuedBy: 'SCHOOL', issuedAt: now, mustChangePassword: true, lastLoginAt: null });
      writeAudit(t, actor, 'STUDENTS', 'student.credentials.issue', `${name}: Parvoz kirish maʼlumotlari berildi`, student.id, null, null, { name });
      return { login, temporaryPassword, issuedAt: now };
    });
  },

  /** Bolaning ochiq parol tiklash so'rovlari (eng yangisi birinchi). */
  async recoveryRequests(studentId: string): Promise<RecoveryRequest[]> {
    await latency(40, 100);
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    const t = getTables();
    return openRecoveryOf(t.access, studentInScope(t, actor, studentId).id);
  },

  /** Bolaning parol tiklash so'rovini rad etish (parol o'zgarmaydi). */
  async rejectRecovery(studentId: string, requestId: string): Promise<void> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'students.manage');
    transact((t) => {
      const student = studentInScope(t, actor, studentId);
      const request = t.access.recoveryRequests.find((r) => r.id === requestId && r.studentId === student.id);
      if (!request) throw new ServiceError('NOT_FOUND', requestId);
      if (request.status !== 'RECEIVED') throw new ServiceError('CONFLICT', 'already resolved');
      request.status = 'REJECTED';
      request.resolvedAt = toLocalIso(clockNow());
      const name = studentName(student);
      writeAudit(t, actor, 'STUDENTS', 'student.recovery.reject', `${name}: parol tiklash soʻrovi rad etildi`, student.id, null, null, { name });
    });
  },

  /** Faol kod va ikki o'rin holati; faol kod yo'q bo'lsa `null`. */
  async inviteCode(studentId: string): Promise<InviteCode | null> {
    await latency(40, 100);
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    const t = getTables();
    const student = studentInScope(t, actor, studentId);
    const active = activeInviteOf(t.access.inviteCodes, student.id, clockNow().getTime());
    return active ? toInviteCodeView(active) : null;
  },

  /** Yangi 6 xonali kod (24 soat); oldingi faol kod yopiladi. */
  async generateInviteCode(studentId: string): Promise<InviteCode> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'guardians.link');
    return transact((t) => {
      const student = studentInScope(t, actor, studentId);
      const now = clockNow();
      const stamp = toLocalIso(now);
      for (const invite of t.access.inviteCodes) {
        if (invite.studentId === student.id && invite.closedAt === null) invite.closedAt = stamp;
      }
      const invite = {
        id: newId('inv'),
        studentId: student.id,
        code: uniqueInviteCode(t.access.inviteCodes, now.getTime()),
        createdAt: stamp,
        expiresAt: toLocalIso(new Date(now.getTime() + INVITE_TTL_HOURS * HOUR_MS)),
        studentUsedAt: null,
        parentUsedAt: null,
        closedAt: null,
        createdByStaffId: actor.staffId,
      };
      t.access.inviteCodes.push(invite);
      const name = studentName(student);
      writeAudit(t, actor, 'GUARDIANS', 'student.inviteCode.create', `${name}: maktab taklif kodi yaratildi`, student.id, null, null, { name });
      return toInviteCodeView(invite);
    });
  },
};
