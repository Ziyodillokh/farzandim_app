// Xodim ulanish so'rovini hal qilganda push: ota-ona "Tasdiq kutilmoqda"da, bola "ulanmagan"da qolib ketmasin.
// Ota-ona tasdig'i — maktab va farzand ismi bilan; rad — ismsiz. Bolaga — har doim neytral (maktab nomisiz).
// Takroriy (idempotent) qaror qayta push yubormaydi.

import { randomUUID } from 'node:crypto';
import { resetDb } from './db';
import { appReq } from './school-child-fixtures';
import {
  buildCodeWorld,
  childLink,
  CodeWorld,
  confirm,
  confirmedLink,
  Family,
  issueCode,
  newFamily,
  parentLink,
  reject,
  resetLinkLimits,
} from './school-student-code-fixtures';
import { createTestApp, TestApp } from './test-app';

const LINK = 'SCHOOL_LINK';

describe('School link decisions notify the parent and the child', () => {
  let t: TestApp;
  let w: CodeWorld;
  let schoolName: string;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    resetLinkLimits(t);
    w = await buildCodeWorld(t);
    schoolName = (await t.prisma.school.findUniqueOrThrow({ where: { id: w.schoolId } })).name;
    t.fcm.reset();
  });

  afterAll(() => t.close());

  const linkPushes = (userId: string) => t.fcm.pushesTo(userId).filter((p) => p.data?.type === LINK);

  /** Bola kodni kiritadi (ota-onasiz) -> UNDER_REVIEW; xodim navbatidagi id. */
  async function childPending(family: Family, studentId: string): Promise<string> {
    const code = await issueCode(t, w.director, studentId);
    expect((await childLink(t, family.child, code)).json().student.status).toBe('UNDER_REVIEW');
    const invite = await t.prisma.schoolStudentInvite.findFirstOrThrow({ where: { studentId, studentChildId: family.child.childId } });
    return `${invite.id}:${family.child.childId}`;
  }

  /** Maktab bilmaydigan ota-ona 6 raqamli kodni kiritadi -> vasiylik so'rovi id'si. */
  async function guardianPending(family: Family, studentId: string): Promise<string> {
    const code = await issueCode(t, w.director, studentId);
    expect((await parentLink(t, family.parent, code)).statusCode).toBe(200);
    return (await t.prisma.schoolGuardianReview.findFirstOrThrow({ where: { userId: family.parent.userId } })).id;
  }

  it('confirming a child request sends one neutral push; a repeated confirm sends nothing', async () => {
    const family = await newFamily(t, 'Aziz');
    const id = await childPending(family, w.aziz.id);
    t.fcm.reset();

    expect((await confirm(t, w.director, id)).statusCode).toBe(200);
    const [push] = linkPushes(family.child.userId);
    expect(linkPushes(family.child.userId)).toHaveLength(1);
    expect(push).toMatchObject({ data: { type: LINK, event: 'CONFIRMED' } });
    expect(`${push!.title} ${push!.body}`).not.toContain(schoolName);
    expect(linkPushes(family.parent.userId)).toHaveLength(0);

    expect((await confirm(t, w.director, id)).statusCode).toBe(200);
    expect(linkPushes(family.child.userId)).toHaveLength(1);
  });

  it('rejecting a child request tells the child to ask for a new code', async () => {
    const family = await newFamily(t, 'Aziz');
    const id = await childPending(family, w.aziz.id);
    t.fcm.reset();

    expect((await reject(t, w.homeroomA, id)).statusCode).toBe(200);
    expect(linkPushes(family.child.userId)).toEqual([expect.objectContaining({ data: { type: LINK, event: 'REJECTED' } })]);
  });

  it('confirming a guardian review names the school and the student, and opens the waiting child too', async () => {
    const family = await newFamily(t, 'Aziz', 'Karimova');
    await childPending(family, w.aziz.id);
    const id = await guardianPending(family, w.aziz.id);
    t.fcm.reset();

    expect((await confirm(t, w.admin, id)).statusCode).toBe(200);
    const parent = linkPushes(family.parent.userId);
    expect(parent).toHaveLength(1);
    expect(parent[0]).toMatchObject({ data: { type: LINK, event: 'GUARDIAN_CONFIRMED' } });
    expect(parent[0]!.title).toContain(schoolName);
    expect(parent[0]!.body).toContain('Aziz');
    expect(linkPushes(family.child.userId)).toEqual([expect.objectContaining({ data: { type: LINK, event: 'CONFIRMED' } })]);
  });

  it('rejecting a guardian review never reveals the school or the student', async () => {
    const family = await newFamily(t, 'Bola', 'Begona');
    const id = await guardianPending(family, w.aziz.id);
    t.fcm.reset();

    expect((await reject(t, w.director, id)).statusCode).toBe(200);
    const [push] = linkPushes(family.parent.userId);
    expect(linkPushes(family.parent.userId)).toHaveLength(1);
    expect(push).toMatchObject({ data: { type: LINK, event: 'GUARDIAN_REJECTED' } });
    const text = `${push!.title} ${push!.body}`;
    expect(text).not.toContain(schoolName);
    expect(text).not.toContain('Aziz');
    expect(text).not.toContain('Karimov');

    expect((await reject(t, w.director, id)).statusCode).toBe(200);
    expect(linkPushes(family.parent.userId)).toHaveLength(1);
  });

  it('a correction decision tells the child whether the link was kept or removed', async () => {
    const kept = await newFamily(t, 'Aziz');
    const removed = await newFamily(t, 'Sardor');
    await confirmedLink(t, w.director, w.aziz, kept);
    await confirmedLink(t, w.director, w.sardor, removed);
    const correction = async (family: Family) => {
      const res = await appReq(t, family.child.token, 'POST', '/child/school/correction', {
        reason: 'WRONG_SCHOOL_OR_CLASS',
        note: 'Sinf noto‘g‘ri',
        clientRequestId: randomUUID(),
      });
      expect(res.statusCode).toBe(201);
      return (await t.prisma.schoolLinkCorrection.findFirstOrThrow({ where: { childId: family.child.childId } })).id;
    };
    const keepId = await correction(kept);
    const removeId = await correction(removed);
    t.fcm.reset();

    expect((await confirm(t, w.director, keepId)).statusCode).toBe(200);
    expect((await reject(t, w.director, removeId)).statusCode).toBe(200);
    expect(linkPushes(kept.child.userId)).toEqual([expect.objectContaining({ data: { type: LINK, event: 'CORRECTION_KEPT' } })]);
    expect(linkPushes(removed.child.userId)).toEqual([expect.objectContaining({ data: { type: LINK, event: 'UNLINKED' } })]);
  });
});
