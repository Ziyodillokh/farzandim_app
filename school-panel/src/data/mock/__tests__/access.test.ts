import { beforeEach, describe, expect, it } from 'vitest';

import { LOGIN_PATTERN } from '@/data/schemas/access';
import { auditText } from '@/features/audit/audit-text';
import { type TKey, translate } from '@/i18n/translate';
import type { Vars } from '@/i18n/types';
import { roleHas } from '@/auth/permissions';
import { accessNotificationId, TEMP_PASSWORD_ALPHABET } from '../access-model';
import { clockNow } from '../clock';
import { currentActor } from '../context';
import { getTables, transact } from '../db';
import { accessService } from '../services/access';
import { buildFeed } from '../services/notifications';
import { freshDb, loginAs } from './helpers';

const ru = (key: TKey, vars?: Vars) => translate('ru', key, vars);
const uz = (key: TKey, vars?: Vars) => translate('uz', key, vars);

/** Ulangan, kirish ma'lumoti hali yo'q o'quvchi (qo'lda tayyorlanadi: seed holatiga bog'liq emas). */
function linkedWithoutCredentials(): string {
  const t = getTables();
  const withCredential = new Set(t.access.credentials.map((c) => c.studentId));
  const id = t.access.linkedStudentIds.find((s) => !withCredential.has(s));
  if (!id) throw new Error('seed: kirish ma\'lumotsiz ulangan o\'quvchi kerak');
  return id;
}

function linkedWithCredentials(classId?: string): string {
  const t = getTables();
  const cred = t.access.credentials.find((c) => !classId || t.students.find((s) => s.id === c.studentId)?.classId === classId);
  if (!cred) throw new Error('seed: kirish ma\'lumotli ulangan o\'quvchi kerak');
  return cred.studentId;
}

function unlinkedStudent(classId = 'cls-7a'): string {
  const t = getTables();
  const linked = new Set(t.access.linkedStudentIds);
  const id = t.students.find((s) => s.classId === classId && !s.archived && !linked.has(s.id))?.id;
  if (!id) throw new Error('seed: ulanmagan o\'quvchi kerak');
  return id;
}

/** O'quvchini arxivga olish (soxta: to'g'ridan-to'g'ri jadvalda). */
function archive(studentId: string): void {
  transact((t) => {
    const student = t.students.find((s) => s.id === studentId);
    if (student) student.archived = true;
  });
}

const studentIn = (classId: string): string => {
  const id = getTables().students.find((s) => s.classId === classId && !s.archived)?.id;
  if (!id) throw new Error(classId);
  return id;
};

describe('accessService.credentials', () => {
  beforeEach(() => {
    freshDb();
    loginAs('DIRECTOR');
  });

  it('ulanmagan o\'quvchi — linked: false (xato emas)', async () => {
    await expect(accessService.credentials(unlinkedStudent())).resolves.toEqual({ linked: false, credentials: null });
  });

  it('ulangan, lekin berilmagan — linked: true, credentials: null', async () => {
    await expect(accessService.credentials(linkedWithoutCredentials())).resolves.toEqual({ linked: true, credentials: null });
  });

  it('berilgan — aynan kontrakt maydonlari (studentId va parol yo\'q)', async () => {
    const view = await accessService.credentials(linkedWithCredentials());
    expect(view.linked).toBe(true);
    expect(Object.keys(view.credentials ?? {}).sort()).toEqual(['issuedAt', 'issuedBy', 'lastLoginAt', 'login', 'mustChangePassword']);
  });

  it('arxivdagi o\'quvchida ma\'lumot o\'qiladi (K1: berish/tiklash taqiqlangan, o\'qish mumkin)', async () => {
    const id = linkedWithCredentials();
    archive(id);
    const view = await accessService.credentials(id);
    expect(view.linked).toBe(true);
    expect(view.credentials).not.toBeNull();
  });

  it('ruxsat: faqat `students.manage` — sinf rahbari va psixolog uchun FORBIDDEN; noma\'lum o\'quvchi — NOT_FOUND', async () => {
    const id = linkedWithCredentials();
    loginAs('HOMEROOM');
    await expect(accessService.credentials(id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('PSYCHOLOGIST');
    await expect(accessService.credentials(id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('ADMIN');
    await expect(accessService.credentials('stu-yoq')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('accessService.issueCredentials', () => {
  beforeEach(() => {
    freshDb();
    loginAs('DIRECTOR');
  });

  it('birinchi berish: login, 8 belgili parol, mustChangePassword=true, issuedBy=SCHOOL', async () => {
    const id = linkedWithoutCredentials();
    const issued = await accessService.issueCredentials(id);
    expect(LOGIN_PATTERN.test(issued.login)).toBe(true);
    expect(issued.temporaryPassword).toHaveLength(8);
    expect([...issued.temporaryPassword].every((ch) => TEMP_PASSWORD_ALPHABET.includes(ch))).toBe(true);
    const view = await accessService.credentials(id);
    expect(view.credentials).toMatchObject({ login: issued.login, issuedBy: 'SCHOOL', mustChangePassword: true, lastLoginAt: null, issuedAt: issued.issuedAt });
  });

  it('PAROL bazaga, auditga yoki keyingi javoblarga tushmaydi', async () => {
    const id = linkedWithoutCredentials();
    const { temporaryPassword } = await accessService.issueCredentials(id);
    expect(JSON.stringify(getTables())).not.toContain(temporaryPassword);
    expect(JSON.stringify(await accessService.credentials(id))).not.toContain(temporaryPassword);
    const reset = await accessService.issueCredentials(id);
    expect(JSON.stringify(getTables().audit)).not.toContain(reset.temporaryPassword);
  });

  it('berilgan login (kichik harfga o\'tkaziladi) qabul qilinadi', async () => {
    const issued = await accessService.issueCredentials(linkedWithoutCredentials(), { login: '  Test.Bola7 ' });
    expect(issued.login).toBe('test.bola7');
  });

  it('band login — CONFLICT/LOGIN_TAKEN; hech narsa yozilmaydi', async () => {
    const existing = getTables().access.credentials[0]!;
    const id = linkedWithoutCredentials();
    await expect(accessService.issueCredentials(id, { login: existing.login })).rejects.toMatchObject({ code: 'CONFLICT', detail: 'LOGIN_TAKEN' });
    await expect(accessService.credentials(id)).resolves.toEqual({ linked: true, credentials: null });
  });

  it('yaroqsiz login — VALIDATION (errors.form.invalidLogin)', async () => {
    const id = linkedWithoutCredentials();
    for (const login of ['ab', '1abc', 'a bcd', 'juda.uzun.login.nomi.bu.yerda', 'ab-cd']) {
      await expect(accessService.issueCredentials(id, { login })).rejects.toMatchObject({ code: 'VALIDATION', message: 'login: errors.form.invalidLogin' });
    }
  });

  it('ulanmagan o\'quvchi — CONFLICT/NOT_LINKED (ota-ona roziligisiz hisob yo\'q)', async () => {
    await expect(accessService.issueCredentials(unlinkedStudent())).rejects.toMatchObject({ code: 'CONFLICT', detail: 'NOT_LINKED' });
    expect(getTables().access.credentials.some((c) => c.studentId === unlinkedStudent())).toBe(false);
  });

  it('tiklash: login o\'zgarmaydi, yangi parol, mustChangePassword=true, ochiq tiklash so\'rovlari RESTORED', async () => {
    const t = getTables();
    const request = t.access.recoveryRequests.find((r) => r.status === 'RECEIVED')!;
    const before = (await accessService.credentials(request.studentId)).credentials!;
    const first = await accessService.issueCredentials(request.studentId, { signOutDevices: true });
    const second = await accessService.issueCredentials(request.studentId, { signOutDevices: false });
    expect(first.login).toBe(before.login);
    expect(second.login).toBe(before.login);
    expect(second.temporaryPassword).not.toBe(first.temporaryPassword);
    const after = (await accessService.credentials(request.studentId)).credentials!;
    expect(after).toMatchObject({ mustChangePassword: true, issuedBy: 'SCHOOL', lastLoginAt: before.lastLoginAt });
    expect(getTables().access.recoveryRequests.find((r) => r.id === request.id)).toMatchObject({ status: 'RESTORED' });
    await expect(accessService.recoveryRequests(request.studentId)).resolves.toEqual([]);
  });

  it('arxivdagi o\'quvchiga berish/tiklash — CONFLICT/STUDENT_ARCHIVED; ulanmagan bo\'lsa NOT_LINKED ustun (backend tartibi)', async () => {
    const id = linkedWithoutCredentials();
    archive(id);
    await expect(accessService.issueCredentials(id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'STUDENT_ARCHIVED' });
    await expect(accessService.credentials(id)).resolves.toEqual({ linked: true, credentials: null });
    const withCredentials = linkedWithCredentials();
    archive(withCredentials);
    await expect(accessService.issueCredentials(withCredentials)).rejects.toMatchObject({ detail: 'STUDENT_ARCHIVED' });
    const unlinked = unlinkedStudent();
    archive(unlinked);
    await expect(accessService.issueCredentials(unlinked)).rejects.toMatchObject({ detail: 'NOT_LINKED' });
  });

  it('audit (K1): `student.credential.issue` / `student.credential.reset` — parolsiz va loginsiz, ikkala tilda tarjima bilan', async () => {
    const id = linkedWithoutCredentials();
    const issued = await accessService.issueCredentials(id);
    await accessService.issueCredentials(id, { signOutDevices: true });
    await accessService.issueCredentials(id, { signOutDevices: false });
    const entries = getTables().audit.filter((a) => a.action.startsWith('student.credential'));
    // Backend'da variant yo'q: ikkala tiklash bir xil amal.
    expect(entries.map((a) => [a.action, a.module, Object.keys(a.params ?? {}).join()])).toEqual([
      ['student.credential.issue', 'STUDENTS', 'name'],
      ['student.credential.reset', 'STUDENTS', 'name'],
      ['student.credential.reset', 'STUDENTS', 'name'],
    ]);
    const name = entries[0]!.params!.name as string;
    expect(auditText(uz, entries[0]!)).toBe(`${name}: Parvoz kirish maʼlumotlari berildi`);
    expect(auditText(uz, entries[1]!)).toBe(`${name}: kirish maʼlumotlari qayta tiklandi (yangi vaqtinchalik parol)`);
    expect(auditText(ru, entries[0]!)).toBe(`${name}: выданы данные для входа в Parvoz`);
    expect(auditText(ru, entries[2]!)).toBe(`${name}: данные для входа восстановлены (новый временный пароль)`);
    for (const e of entries) {
      expect(e.before).toBeNull();
      expect(e.after).toBeNull();
      expect(JSON.stringify(e)).not.toContain(issued.login);
    }
  });

  it('sinf rahbari berolmaydi (students.manage yo\'q)', async () => {
    loginAs('HOMEROOM');
    await expect(accessService.issueCredentials(linkedWithoutCredentials())).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('accessService: parol tiklash so\'rovlari', () => {
  beforeEach(() => {
    freshDb();
    loginAs('ADMIN');
  });

  it('ochiq so\'rovlar — eng yangisi birinchi, faqat id, kanal va vaqt', async () => {
    const requests = getTables().access.recoveryRequests.filter((r) => r.status === 'RECEIVED');
    const sevenA = requests.find((r) => getTables().students.find((s) => s.id === r.studentId)?.classId === 'cls-7a')!;
    const list = await accessService.recoveryRequests(sevenA.studentId);
    expect(list).toEqual([{ id: sevenA.id, channel: 'SCHOOL', createdAt: sevenA.createdAt }]);
  });

  it('rad etish: so\'rov ro\'yxatdan chiqadi, parol o\'zgarmaydi, audit; qayta rad etish — CONFLICT/ALREADY_RESOLVED', async () => {
    const request = getTables().access.recoveryRequests.find((r) => r.status === 'RECEIVED')!;
    const before = await accessService.credentials(request.studentId);
    await accessService.rejectRecovery(request.studentId, request.id);
    expect(getTables().access.recoveryRequests.find((r) => r.id === request.id)).toMatchObject({ status: 'REJECTED' });
    await expect(accessService.recoveryRequests(request.studentId)).resolves.toEqual([]);
    await expect(accessService.credentials(request.studentId)).resolves.toEqual(before);
    expect(getTables().audit.at(-1)).toMatchObject({ action: 'student.recovery.reject', module: 'STUDENTS' });
    await expect(accessService.rejectRecovery(request.studentId, request.id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'ALREADY_RESOLVED' });
  });

  it('rad etish va tiklash hal bo\'lgan so\'rovning xodim bildirishnomasini o\'chiradi (K1 §5)', async () => {
    const [first, second] = getTables().access.recoveryRequests.filter((r) => r.status === 'RECEIVED');
    const noteIds = () => getTables().notifications.filter((n) => n.kind === 'CHILD_RECOVERY_REQUEST').map((n) => n.id);
    expect(noteIds()).toEqual(expect.arrayContaining([accessNotificationId('CHILD_RECOVERY_REQUEST', first!.id), accessNotificationId('CHILD_RECOVERY_REQUEST', second!.id)]));
    await accessService.rejectRecovery(first!.studentId, first!.id);
    expect(noteIds()).toEqual([accessNotificationId('CHILD_RECOVERY_REQUEST', second!.id)]);
    await accessService.issueCredentials(second!.studentId);
    expect(noteIds()).toEqual([]);
  });

  it('ulanmagan o\'quvchi — rad etish CONFLICT/NOT_LINKED (backend: avval ulanish tekshiriladi)', async () => {
    await expect(accessService.rejectRecovery(unlinkedStudent(), 'rec-1')).rejects.toMatchObject({ code: 'CONFLICT', detail: 'NOT_LINKED' });
  });

  it('boshqa o\'quvchining so\'rovi yoki noma\'lum id — NOT_FOUND', async () => {
    const [a, b] = getTables().access.recoveryRequests.filter((r) => r.status === 'RECEIVED');
    await expect(accessService.rejectRecovery(a!.studentId, b!.id)).rejects.toMatchObject({ code: 'NOT_FOUND', detail: 'REQUEST_NOT_FOUND' });
    await expect(accessService.rejectRecovery(a!.studentId, 'rec-yoq')).rejects.toMatchObject({ code: 'NOT_FOUND', detail: 'REQUEST_NOT_FOUND' });
  });

  it('sinf rahbari (students.manage yo\'q) — FORBIDDEN', async () => {
    const request = getTables().access.recoveryRequests.find((r) => r.status === 'RECEIVED')!;
    loginAs('HOMEROOM');
    await expect(accessService.recoveryRequests(request.studentId)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(accessService.rejectRecovery(request.studentId, request.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('accessService: 6 xonali taklif kodi', () => {
  beforeEach(() => {
    freshDb();
    loginAs('DIRECTOR');
  });

  it('kod yaratish: 6 raqam, 24 soat, ikkala o\'rin bo\'sh; keyingi o\'qishda shu kod', async () => {
    const id = linkedWithoutCredentials();
    await expect(accessService.inviteCode(id)).resolves.toBeNull();
    const created = await accessService.generateInviteCode(id);
    expect(created.code).toMatch(/^\d{6}$/);
    expect(created.student).toEqual({ status: 'FREE', usedAt: null });
    expect(created.parent).toEqual({ status: 'FREE', usedAt: null });
    const lifetime = Date.parse(created.expiresAt) - clockNow().getTime();
    expect(Math.abs(lifetime - 24 * 3_600_000)).toBeLessThan(10_000);
    await expect(accessService.inviteCode(id)).resolves.toEqual(created);
  });

  it('yangi kod oldingisini yopadi: o\'quvchida faqat bitta faol kod', async () => {
    const id = linkedWithoutCredentials();
    const first = await accessService.generateInviteCode(id);
    const second = await accessService.generateInviteCode(id);
    const mine = getTables().access.inviteCodes.filter((c) => c.studentId === id);
    expect(mine).toHaveLength(2);
    expect(mine.filter((c) => c.closedAt === null)).toHaveLength(1);
    expect((await accessService.inviteCode(id))?.code).toBe(second.code);
    expect(mine.find((c) => c.code === first.code && c.closedAt !== null)).toBeDefined();
  });

  it('seed: bola kiritgan faol kod — o\'quvchi o\'rni UNDER_REVIEW, ota-ona o\'rni FREE; ikkala o\'rin band kod yopiq — faol kod yo\'q', async () => {
    const review = getTables().access.linkRequests.filter((r) => r.kind === 'REVIEW');
    expect(review.some((r) => r.parentLinked)).toBe(true);
    for (const r of review) {
      const invite = await accessService.inviteCode(r.studentId);
      if (r.parentLinked) {
        expect(invite).toBeNull();
      } else {
        expect(invite?.student.status).toBe('UNDER_REVIEW');
        expect(invite?.student.usedAt).toBe(r.createdAt);
        expect(invite?.parent).toEqual({ status: 'FREE', usedAt: null });
      }
    }
  });

  it('arxivdagi o\'quvchi: kod o\'qiladi, lekin yangi kod yaratib bo\'lmaydi — CONFLICT/STUDENT_ARCHIVED', async () => {
    const id = linkedWithoutCredentials();
    const created = await accessService.generateInviteCode(id);
    archive(id);
    await expect(accessService.inviteCode(id)).resolves.toEqual(created);
    await expect(accessService.generateInviteCode(id)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'STUDENT_ARCHIVED' });
    expect(getTables().access.inviteCodes.filter((c) => c.studentId === id && c.closedAt === null)).toHaveLength(1);
  });

  it('muddati o\'tgan kod — faol emas (null)', async () => {
    const id = getTables().access.linkRequests.find((r) => r.kind === 'REVIEW')!.studentId;
    expect(await accessService.inviteCode(id)).not.toBeNull();
    transact((t) => {
      for (const c of t.access.inviteCodes) c.expiresAt = '2026-10-12T09:00:00';
    });
    await expect(accessService.inviteCode(id)).resolves.toBeNull();
  });

  it('ruxsat: sinf rahbari faqat o\'z sinfida; psixolog — FORBIDDEN', async () => {
    loginAs('HOMEROOM');
    const own = studentIn('cls-7a');
    await expect(accessService.generateInviteCode(own)).resolves.toMatchObject({ code: expect.stringMatching(/^\d{6}$/) });
    const other = studentIn('cls-8b');
    await expect(accessService.generateInviteCode(other)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(accessService.inviteCode(other)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('PSYCHOLOGIST');
    await expect(accessService.inviteCode(own)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('DUTY');
    await expect(accessService.generateInviteCode(own)).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('audit kodni o\'zini yozmaydi', async () => {
    const created = await accessService.generateInviteCode(linkedWithoutCredentials());
    const entry = getTables().audit.at(-1)!;
    // K2 §8: `student.inviteCode` (modul GUARDIANS), params `{ name }` — kod yozilmaydi.
    expect(entry).toMatchObject({ action: 'student.inviteCode', module: 'GUARDIANS' });
    expect(Object.keys(entry.params ?? {})).toEqual(['name']);
    expect(JSON.stringify(entry)).not.toContain(created.code);
    expect(auditText(uz, entry)).toMatch(/oʻquvchi kodi yaratildi$/);
    expect(auditText(ru, entry)).toMatch(/создан код ученика$/);
  });
});

describe('xodim bildirishnomalari (kirish)', () => {
  const NOW = new Date(2026, 9, 12, 10, 0, 0);
  beforeEach(freshDb);

  const kinds = (role: Parameters<typeof loginAs>[0]) => {
    loginAs(role);
    return buildFeed(getTables(), currentActor(), NOW).filter((i) => ['CHILD_RECOVERY_REQUEST', 'LINK_REVIEW', 'LINK_CORRECTION'].includes(i.kind));
  };

  it('qabul qiluvchilar — ish qila oladigan xodimlar: direktor va admin hammasini, sinf rahbari faqat o\'z sinfining ulanish bildirishnomalarini; navbatchi/psixolog — yo\'q', () => {
    const admin = kinds('ADMIN');
    expect(admin).toHaveLength(7);
    // Direktor ham `students.manage` va `guardians.link` egasi — endi u ham oladi (kontrakt K1 §5 / K2 §7).
    expect(kinds('DIRECTOR').map((i) => i.id).sort()).toEqual(admin.map((i) => i.id).sort());
    expect(kinds('DUTY')).toHaveLength(0);
    expect(kinds('PSYCHOLOGIST')).toHaveLength(0);
    const homeroom = kinds('HOMEROOM');
    expect(homeroom).toHaveLength(3);
    expect(new Set(homeroom.map((i) => i.params.className))).toEqual(new Set(['7-A']));
  });

  it('bildirishnoma faqat uni hal qila oladigan xodimga: `students.manage`siz sinf rahbariga CHILD_RECOVERY_REQUEST kelmaydi', () => {
    expect(roleHas('HOMEROOM', 'students.manage')).toBe(false);
    const homeroom = kinds('HOMEROOM');
    expect(homeroom.some((i) => i.kind === 'CHILD_RECOVERY_REQUEST')).toBe(false);
    // Ulanish so'rovlarini (`guardians.link`) hal qila oladi — ular keladi.
    expect(new Set(homeroom.map((i) => i.kind))).toEqual(new Set(['LINK_REVIEW', 'LINK_CORRECTION']));
    // Admin va direktor (`students.manage` bor) tiklash so'rovlarini oladi.
    expect(kinds('ADMIN').filter((i) => i.kind === 'CHILD_RECOVERY_REQUEST')).toHaveLength(2);
    expect(kinds('DIRECTOR').filter((i) => i.kind === 'CHILD_RECOVERY_REQUEST')).toHaveLength(2);
  });

  it('ohang (K1 §5, K2 §7): uchala tur ham `warning`; params faqat ism va sinf', () => {
    const items = kinds('ADMIN');
    for (const kind of ['CHILD_RECOVERY_REQUEST', 'LINK_REVIEW', 'LINK_CORRECTION']) {
      expect(items.find((i) => i.kind === kind)?.tone, kind).toBe('warning');
    }
    for (const i of items) expect(Object.keys(i.params).filter((k) => k !== 'count').sort()).toEqual(['className', 'studentName']);
  });

  it('matnlar ikkala tilda ism va sinf bilan', () => {
    const item = kinds('ADMIN').find((i) => i.kind === 'LINK_REVIEW')!;
    const name = String(item.params.studentName);
    expect(translate('uz', `notifications.kind.${item.kind}`, item.params)).toContain(name);
    expect(translate('ru', `notifications.kind.${item.kind}`, item.params)).toContain(name);
    expect(translate('uz', 'notifications.kind.CHILD_RECOVERY_REQUEST', item.params)).toBe(`${name} (${item.params.className}) kirish parolini tiklashni soʻradi`);
  });
});
