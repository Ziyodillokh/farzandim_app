// Maktabning o'z o'quv materiallari: fan o'qituvchisi va direktor ham material qo'shadi va o'z sinflariga yuboradi,
// tahrirlash / arxiv — muallif yoki butun maktab xodimi; bola ilovasida matn + havola, "O'qidim" va xodimga sanoq.

import { resetDb } from './db';
import { TestChild } from './factories';
import { at, DAY, seedWorld, setNow, World } from './school-attendance-fixtures';
import { appReq, linkNewChild, schoolReq } from './school-child-fixtures';
import { createTestApp, TestApp } from './test-app';

const MATERIAL = {
  title: 'Kasrlarni qo\'shish',
  subject: 'MATH',
  grades: [8, 7, 8],
  body: 'Kasrlarni qo\'shishda avval umumiy maxrajni toping.\nKeyin suratlarni qo\'shing.',
  linkUrl: 'https://www.youtube.com/watch?v=abc123',
  estimatedMinutes: 15,
};

describe('School learning materials', () => {
  let t: TestApp;
  let w: World;
  let bekChild: TestChild;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await seedWorld(t);
    setNow(t, at(DAY, '09:00'));
    bekChild = await linkNewChild(t, w.bek, 'Bek');
  });

  afterAll(() => t.close());

  const createMaterial = async (s = w.teacher, over: Record<string, unknown> = {}) => {
    const res = await schoolReq(t, s, 'POST', '/learning/materials', { ...MATERIAL, ...over });
    if (res.statusCode !== 201) throw new Error(`createMaterial ${res.statusCode}: ${res.body}`);
    return res.json() as { id: string };
  };
  const assign = (s: World['teacher'], materialId: string, classIds: string[]) =>
    schoolReq(t, s, 'POST', '/learning/assignments', { materialId, classIds, dueDate: '2099-01-01', note: 'Ertagacha' });

  it('lets a subject teacher add a material, validates it and lists it first with edit rights', async () => {
    const created = await createMaterial();
    expect(created).toMatchObject({ kind: 'LESSON', own: true, title: MATERIAL.title, grades: [7, 8], durationMin: 15, canEdit: true });
    expect(created.id).toMatch(/^school:/);

    expect((await schoolReq(t, w.teacher, 'POST', '/learning/materials', { ...MATERIAL, linkUrl: 'http://example.com' })).statusCode).toBe(400);
    expect((await schoolReq(t, w.teacher, 'POST', '/learning/materials', { ...MATERIAL, linkUrl: 'javascript:alert(1)' })).statusCode).toBe(400);
    expect((await schoolReq(t, w.teacher, 'POST', '/learning/materials', { ...MATERIAL, title: 'ab' })).statusCode).toBe(400);
    expect((await schoolReq(t, w.teacher, 'POST', '/learning/materials', { ...MATERIAL, linkUrl: '' })).json()).toMatchObject({ linkUrl: null });
    expect((await schoolReq(t, w.psych, 'POST', '/learning/materials', MATERIAL)).statusCode).toBe(403);

    // Yangilari tepada, Parvoz katalogidan oldin; boshqa xodim tahrirlay olmaydi.
    const list = (await schoolReq(t, w.homeroom, 'GET', '/learning/materials')).json();
    expect(list.slice(0, 2).map((m: { kind: string }) => m.kind)).toEqual(['LESSON', 'LESSON']);
    expect(list.find((m: { id: string }) => m.id === created.id)).toMatchObject({ kind: 'LESSON', canEdit: false, byName: expect.any(String) });
    expect((await schoolReq(t, w.homeroom, 'GET', '/learning/materials?kind=LESSON')).json()).toHaveLength(2);
    expect(await t.prisma.schoolAuditLog.count({ where: { action: 'learning.materialCreate' } })).toBe(2);
  });

  it('lets the teacher send it only to own classes; the director can send too', async () => {
    const { id } = await createMaterial();
    expect((await assign(w.teacher, id, [w.classA])).statusCode).toBe(403);
    const res = await assign(w.teacher, id, [w.classB]);
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject({ materialKind: 'LESSON', title: MATERIAL.title, estimatedMinutes: 15 });
    expect((await assign(w.director, id, [w.classA])).statusCode).toBe(201);
  });

  it('shows the material to the child, marks it read once and counts reads for staff', async () => {
    const { id } = await createMaterial();
    const assignmentId = (await assign(w.teacher, id, [w.classB])).json().id;

    const [item] = (await appReq(t, bekChild.token, 'GET', '/child/school/assignments')).json();
    expect(item).toMatchObject({
      id: assignmentId,
      kind: 'LESSON',
      title: MATERIAL.title,
      done: false,
      lesson: { body: MATERIAL.body, linkUrl: MATERIAL.linkUrl, readAt: null },
    });
    const read = await appReq(t, bekChild.token, 'POST', `/child/school/assignments/${assignmentId}/read`);
    expect(read.statusCode).toBe(200);
    expect(read.json()).toMatchObject({ id: assignmentId, done: true, readAt: expect.any(String) });
    expect((await appReq(t, bekChild.token, 'POST', `/child/school/assignments/${assignmentId}/read`)).statusCode).toBe(200);
    expect((await appReq(t, bekChild.token, 'GET', '/child/school/assignments')).json()[0]).toMatchObject({ done: true });

    // 7-A bolasi bu topshiriqni ko'rmaydi va belgilay olmaydi.
    expect((await appReq(t, w.child.token, 'POST', `/child/school/assignments/${assignmentId}/read`)).statusCode).toBe(404);
    const staff = (await schoolReq(t, w.teacher, 'GET', '/learning/assignments')).json();
    expect(staff.find((a: { id: string }) => a.id === assignmentId)).toMatchObject({ materialKind: 'LESSON', readCount: 1, subject: 'MATH' });
  });

  it('allows only the author or school-wide staff to edit and archive; archived materials stay readable in sent tasks', async () => {
    const { id } = await createMaterial();
    const assignmentId = (await assign(w.teacher, id, [w.classB])).json().id;

    expect((await schoolReq(t, w.homeroom, 'PUT', `/learning/materials/${id}`, { ...MATERIAL, title: 'Begona tahrir' })).statusCode).toBe(403);
    const edited = await schoolReq(t, w.teacher, 'PUT', `/learning/materials/${id}`, { ...MATERIAL, body: 'Yangilangan izoh' });
    expect(edited.json()).toMatchObject({ body: 'Yangilangan izoh' });

    expect((await schoolReq(t, w.homeroom, 'DELETE', `/learning/materials/${id}`)).statusCode).toBe(403);
    expect((await schoolReq(t, w.admin, 'DELETE', `/learning/materials/${id}`)).statusCode).toBe(204);
    expect((await schoolReq(t, w.admin, 'GET', '/learning/materials?kind=LESSON')).json()).toHaveLength(0);
    expect((await assign(w.teacher, id, [w.classB])).statusCode).toBe(400);

    const [item] = (await appReq(t, bekChild.token, 'GET', '/child/school/assignments')).json();
    expect(item).toMatchObject({ id: assignmentId, kind: 'LESSON', lesson: { body: 'Yangilangan izoh' } });
  });
});
