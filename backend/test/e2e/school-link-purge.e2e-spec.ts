// O'quvchi kodi (K2) — ma'lumotlarni o'chirish: bola / ota-ona / admin yo'llarida bolaning kod yozuvlari,
// tuzatish so'rovlari va ularga bog'liq xodim bildirishnomalari o'chadi; boshqa bolalar, o'quvchi qatorlari saqlanadi.
// Ota-ona o'rnini band qilgan ota-ona akkaunti o'chsa o'rin bo'shaydi.

import { randomUUID } from 'node:crypto';
import { createModerator } from './factories';
import { resetDb } from './db';
import { appReq } from './school-child-fixtures';
import {
  buildCodeWorld,
  childLink,
  CodeWorld,
  confirmedLink,
  currentCode,
  Family,
  issueCode,
  newFamily,
  parentLink,
  resetLinkLimits,
} from './school-student-code-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School student code — data purge (K2)', () => {
  let t: TestApp;
  let w: CodeWorld;
  let gone: Family;
  let waiting: Family;
  let kept: Family;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    resetLinkLimits(t);
    w = await buildCodeWorld(t);
    // gone: tasdiqlangan + ochiq tuzatish; waiting: UNDER_REVIEW; kept: tasdiqlangan + ochiq tuzatish (tegilmasligi shart)
    gone = await newFamily(t, 'Ketadi');
    waiting = await newFamily(t, 'Kutadi');
    kept = await newFamily(t, 'Qoladi');
    await confirmedLink(t, w.director, w.aziz, gone);
    await childLink(t, waiting.child, await issueCode(t, w.director, w.bobur.id));
    await confirmedLink(t, w.director, w.sardor, kept);
    for (const f of [gone, kept]) {
      const res = await appReq(t, f.child.token, 'POST', '/child/school/correction', {
        reason: 'WRONG_SCHOOL_OR_CLASS',
        note: 'Xato',
        clientRequestId: randomUUID(),
      });
      expect(res.statusCode).toBe(201);
    }
  });

  afterAll(() => t.close());

  const rows = (childIds: string[]) =>
    Promise.all([
      t.prisma.schoolStudentInvite.count({ where: { studentChildId: { in: childIds } } }),
      t.prisma.schoolLinkCorrection.count({ where: { childId: { in: childIds } } }),
    ]);

  async function expectErased(childIds: string[]) {
    expect(await rows(childIds)).toEqual([0, 0]);
    // Faqat saqlanib qolgan bolaning (kept) tuzatish bildirishnomasi qoladi; o'quvchi qatorlari tegilmaydi.
    const notes = await t.prisma.schoolStaffNotification.findMany({ where: { kind: { in: ['LINK_REVIEW', 'LINK_CORRECTION'] } } });
    const keptCorrection = await t.prisma.schoolLinkCorrection.findFirstOrThrow({ where: { childId: kept.child.childId } });
    expect(notes.map((n) => n.id)).toEqual([`link-correction:${keptCorrection.id}`]);
    expect(await t.prisma.schoolStudent.count({ where: { schoolId: w.schoolId } })).toBe(3);
    expect(await rows([kept.child.childId])).toEqual([1, 1]);
  }

  it('child deletes its own account (DELETE /users/me)', async () => {
    expect(await rows([gone.child.childId, waiting.child.childId])).toEqual([2, 1]);
    // Kutayotgan bola ham o'z hisobini o'chiradi
    expect((await appReq(t, waiting.child.token, 'DELETE', '/users/me')).statusCode).toBe(200);
    expect((await appReq(t, gone.child.token, 'DELETE', '/users/me')).statusCode).toBe(200);

    await expectErased([gone.child.childId, waiting.child.childId]);
    // Profil qoladi (ota-onaniki) — tasdiqlangan bog'lanish ham; faqat kod yozuvlari ketadi
    expect((await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.aziz.id } })).childId).toBe(gone.child.childId);
  });

  it('parent deletes the child profile (DELETE /children/:id)', async () => {
    const res = await appReq(t, gone.parent.token, 'DELETE', `/children/${gone.child.childId}`);

    expect(res.statusCode).toBe(200);
    expect(await rows([gone.child.childId])).toEqual([0, 0]);
    const notes = await t.prisma.schoolStaffNotification.findMany({ where: { kind: 'LINK_CORRECTION' } });
    expect(notes).toHaveLength(1);
    expect(await rows([kept.child.childId, waiting.child.childId])).toEqual([2, 1]);
    expect((await t.prisma.schoolStudent.findUniqueOrThrow({ where: { id: w.aziz.id } })).childId).toBeNull();
  });

  it('parent deletes the whole account (DELETE /users/me); a parent slot held by the deleted parent is freed', async () => {
    // Ota-ona o'rnini faqat shu ota-ona band qilgan faol kod
    const lonely = await newFamily(t, 'Yolg\'iz');
    const code = await issueCode(t, w.director, w.bobur.id); // yangi kod (oldingi yopiladi, kutayotgan bola yozuvi saqlanadi)
    expect((await parentLink(t, lonely.parent, code)).statusCode).toBe(200);
    expect((await currentCode(t, w.director, w.bobur.id)).json().parent.status).toBe('USED');
    // Ishonchsiz ota-ona: vasiylik so'rovi xodim ko'rigida (+ bildirishnoma)
    expect(await t.prisma.schoolGuardianReview.count({ where: { userId: lonely.parent.userId } })).toBe(1);
    expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'GUARDIAN_REVIEW' } })).toBe(1);

    expect((await appReq(t, lonely.parent.token, 'DELETE', '/users/me')).statusCode).toBe(200);
    expect((await currentCode(t, w.director, w.bobur.id)).json().parent).toMatchObject({ status: 'FREE' });
    expect(await t.prisma.schoolGuardianReview.count()).toBe(0);
    expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'GUARDIAN_REVIEW' } })).toBe(0);

    expect((await appReq(t, gone.parent.token, 'DELETE', '/users/me')).statusCode).toBe(200);
    expect(await rows([gone.child.childId])).toEqual([0, 0]);
    expect(await rows([kept.child.childId])).toEqual([1, 1]);
    const notes = await t.prisma.schoolStaffNotification.findMany({ where: { kind: 'LINK_CORRECTION' } });
    expect(notes).toHaveLength(1);
  });

  it.each(['PARENT', 'CHILD'] as const)('admin deletes the user (%s)', async (kind) => {
    const moderator = await createModerator(t.prisma, ['manage_users']);
    const id = kind === 'PARENT' ? gone.parent.userId : gone.child.userId;

    const res = await t.app.inject({ method: 'DELETE', url: `/api/admin/users/${id}`, headers: { authorization: `Bearer ${moderator.token}` } });

    expect(res.statusCode).toBe(200);
    expect(await rows([gone.child.childId])).toEqual([0, 0]);
    expect(await rows([kept.child.childId])).toEqual([1, 1]);
    expect(await t.prisma.schoolStaffNotification.count({ where: { kind: 'LINK_CORRECTION' } })).toBe(1);
  });

  it('keeps unrelated tokens valid: another family\'s child still sees its link status after the purge', async () => {
    await appReq(t, gone.parent.token, 'DELETE', `/children/${gone.child.childId}`);

    const status = await appReq(t, kept.child.token, 'GET', '/child/school/link-status');

    expect(status.json().student.status).toBe('CORRECTION');
  });
});
