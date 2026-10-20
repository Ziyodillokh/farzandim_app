// Psixologik testlar: ruxsatlar (psixolog / sinf rahbari / direktor / admin /
// navbatchi), tenant izolyatsiyasi, yaratish → nashr → tayinlash → bola yechadi →
// natijalar rolga qarab, versiyalar, shablon me'yorlari (darhol qayta baholash), audit.

import { AssessmentsStore } from '../../src/school/assessments/assessments-store';
import { resetDb } from './db';
import { AssessWorld, buildWorld, childApi, L, openWindow, publishedAssignment, sampleInput, staffApi, staffWith } from './school-assessments-fixtures';
import { createSchool } from './school-fixtures';
import { createClass } from './school-students-fixtures';
import { createTestApp, TestApp } from './test-app';

const ALL_A = { q1: 'a', q2: 'b', q3: 'a', q4: 'b' };

describe('School assessments — ruxsatlar va oqim', () => {
  let t: TestApp;
  let w: AssessWorld;
  let api: ReturnType<typeof staffApi>;
  let child: ReturnType<typeof childApi>;

  beforeAll(async () => {
    t = await createTestApp();
    api = staffApi(t);
    child = childApi(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await buildWorld(t);
  });

  afterAll(() => t.close());

  it.each(['director', 'admin', 'homeroom', 'duty', 'teacher'] as const)('%s kutubxona, tayinlash va importga kira olmaydi (403)', async (role) => {
    const who = w[role];
    const calls = await Promise.all([
      api(who, 'GET', '/tests'),
      api(who, 'GET', '/tests/tpl-logic'),
      api(who, 'POST', '/tests', sampleInput()),
      api(who, 'GET', '/assignments'),
      api(who, 'GET', '/class-options'),
      api(who, 'POST', '/assignments', { testId: 'tpl-logic', target: { kind: 'CLASSES', classIds: [w.classes.c7a] }, ...openWindow(), consent: true }),
      api(who, 'GET', '/tests/tpl-logic/export'),
      api(who, 'POST', '/results/csv/preview', { text: 'studentCode;test;date;raw\n' }),
      api(who, 'PUT', '/tests/tpl-logic/norms', { norms: null }),
    ]);
    for (const res of calls) expect({ status: res.statusCode, code: res.json().code }).toEqual({ status: 403, code: 'FORBIDDEN' });
  });

  it('direktor, admin, navbatchi va o\'qituvchi natijalarni ko\'rmaydi; sinf rahbari — faqat o\'z sinfi', async () => {
    for (const who of [w.director, w.admin, w.duty, w.teacher]) expect((await api(who, 'GET', '/tests/tpl-logic/results')).statusCode).toBe(403);
    expect((await api(w.homeroom, 'GET', `/tests/tpl-logic/results?classId=${w.classes.c7b}`)).statusCode).toBe(403);
    const own = await api(w.homeroom, 'GET', `/tests/tpl-logic/results?classId=${w.classes.c7a}`);
    expect(own.json()).toMatchObject({ rows: [], bandsOnly: true, participation: { invited: 3, completed: 0 } });
  });

  it('psixolog 6 shablonni ko\'radi; filtr va qidiruv', async () => {
    const tests = (await api(w.psych, 'GET', '/tests')).json();
    expect(tests.filter((x: { source: string }) => x.source === 'TEMPLATE')).toHaveLength(6);
    expect(tests.find((x: { id: string }) => x.id === 'tpl-logic')).toMatchObject({ itemCount: 16, assignmentsActive: 0, resultsCount: 0, status: 'PUBLISHED', version: 1 });
    expect((await api(w.psych, 'GET', '/tests?kind=CAREER')).json().map((x: { id: string }) => x.id)).toEqual(['tpl-career']);
    expect((await api(w.psych, 'GET', '/tests?search=xotira')).json().map((x: { id: string }) => x.id)).toEqual(['tpl-attention']);
    expect((await api(w.psych, 'GET', '/tests?status=NOPE')).statusCode).toBe(400);
    const detail = (await api(w.psych, 'GET', '/tests/tpl-logic')).json();
    expect(detail).toMatchObject({ readOnly: true, normsOverridden: false, updatedAt: '2026-09-01T04:00:00.000Z' });
    expect(detail.defaultNorms.total).toHaveLength(5);
    expect((await api(w.psych, 'GET', '/tests/nope')).statusCode).toBe(404);
    const options = (await api(w.psych, 'GET', '/class-options')).json();
    expect(options.map((c: { name: string; size: number }) => [c.name, c.size])).toEqual([['5-A', 0], ['7-A', 3], ['7-B', 2]]);
  });

  it('yaratish → nashr → tayinlash → bola yechadi → natijalar rolga qarab', async () => {
    const c10 = await createClass(t.prisma, w.schoolId, 10, 'A');
    const draft = (await api(w.psych, 'POST', '/tests', sampleInput())).json();
    expect(draft).toMatchObject({ source: 'CUSTOM', status: 'DRAFT', version: 1, basedOn: null, createdBy: w.psych.staffId });
    const target = { kind: 'CLASSES', classIds: [w.classes.c7a, w.classes.c7b, c10.id] };
    expect((await api(w.psych, 'POST', '/assignments', { testId: draft.id, target, ...openWindow(), consent: true })).statusCode).toBe(409);
    expect((await api(w.psych, 'POST', `/tests/${draft.id}/publish`)).json()).toMatchObject({ status: 'PUBLISHED' });
    const a = (await api(w.psych, 'POST', '/assignments', { testId: draft.id, target, ...openWindow(), consent: true })).json();
    expect(a.classIds.sort()).toEqual([w.classes.c7a, w.classes.c7b].sort());
    expect(a).toMatchObject({ invited: 5, status: 'OPEN', testVersion: 1, consent: 'PARENTS_INFORMED' });

    const answers = [ALL_A, { q1: 'a', q2: 'a', q3: 'a', q4: 'a' }, { q1: 'b' }];
    for (const [i, kid] of w.kids7a.entries()) {
      expect((await child(kid, 'POST', `/${a.id}/submit`, { answers: answers[i], durationSec: 100 + i })).statusCode).toBe(201);
    }
    await child(w.kids7b[0]!, 'POST', `/${a.id}/submit`, { answers: ALL_A });

    const full = (await api(w.psych, 'GET', `/tests/${draft.id}/results?assignmentId=${a.id}`)).json();
    expect(full).toMatchObject({ bandsOnly: false, scaleKey: 'total', needsNorms: false, participation: { invited: 5, completed: 4 } });
    const top = full.rows.find((r: { studentId: string }) => r.studentId === w.kids7a[0]!.studentId);
    expect(top).toMatchObject({ origin: 'APP', ageBand: 'A13_14', className: '7-A', studentName: 'Alfaov Alfa0', durationSec: 100, answers: '0101' });
    expect(top.scales[0]).toMatchObject({ key: 'total', raw: 4, max: 4, standard: 130, percentile: 98, band: 'VERY_HIGH' });
    expect(full.distribution.reduce((s: number, b: { count: number }) => s + b.count, 0)).toBe(4);

    const banded = (await api(w.homeroom, 'GET', `/tests/${draft.id}/results`)).json();
    expect(banded).toMatchObject({ bandsOnly: true, participation: { invited: 3, completed: 3 } });
    expect(banded.rows).toHaveLength(3);
    for (const row of banded.rows) {
      expect(row.classId).toBe(w.classes.c7a);
      expect(row.answers).toBeUndefined();
      expect(row.durationSec).toBeUndefined();
      expect(row.topCodes).toBeNull();
      for (const s of row.scales) expect(Object.keys(s).sort()).toEqual(['band', 'key']);
    }

    const rows = (await api(w.psych, 'GET', `/assignments?testId=${draft.id}`)).json();
    expect(rows[0]).toMatchObject({ id: a.id, state: 'ACTIVE', completed: 4, testTitle: L('Sinov testi'), testKind: 'CUSTOM' });
    expect(rows[0].classNames.sort()).toEqual(['7-A', '7-B']);
    expect((await api(w.psych, 'GET', '/assignments?state=ENDED')).json()).toEqual([]);
    expect((await api(w.psych, 'GET', '/tests')).json().find((x: { id: string }) => x.id === draft.id)).toMatchObject({ assignmentsActive: 1, resultsCount: 4 });

    const notes = await t.prisma.schoolStaffNotification.findMany({ where: { kind: 'TEST_COMPLETED' } });
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({ roles: ['PSYCHOLOGIST'], classIds: [], params: { count: 4 }, subject: L('Sinov testi'), href: `/assessments?tab=results&test=${draft.id}` });
    expect(JSON.stringify(notes)).not.toMatch(/Alfa|Beta/);
  });

  it('versiya: nashr etilgan testda savol o\'zgarsa oshadi, faqat nom o\'zgarsa — yo\'q; eski natija o\'z versiyasida', async () => {
    const draft = (await api(w.psych, 'POST', '/tests', sampleInput())).json();
    const items3 = sampleInput().items.slice(0, 3);
    expect((await api(w.psych, 'PUT', `/tests/${draft.id}`, sampleInput({ items: items3 }))).json().version).toBe(1);
    await api(w.psych, 'POST', `/tests/${draft.id}/publish`);
    expect((await api(w.psych, 'PUT', `/tests/${draft.id}`, sampleInput({ title: L('Yangi nom'), items: items3 }))).json()).toMatchObject({ version: 1, title: L('Yangi nom') });
    const a = (await api(w.psych, 'POST', '/assignments', { testId: draft.id, target: { kind: 'GRADES', grades: [7] }, ...openWindow(), consent: true })).json();
    expect(a.testVersion).toBe(1);
    await child(w.kids7a[0]!, 'POST', `/${a.id}/submit`, { answers: { q1: 'a' } });
    const bumped = (await api(w.psych, 'PUT', `/tests/${draft.id}`, sampleInput({ title: L('Yangi nom') }))).json();
    expect(bumped).toMatchObject({ version: 2, status: 'PUBLISHED' });
    const again = (await api(w.psych, 'PUT', `/tests/${draft.id}`, sampleInput({ title: L('Uchinchi nom') }))).json();
    expect(again.version).toBe(2);
    expect((await t.prisma.schoolPsychResult.findFirstOrThrow()).version).toBe(1);
    const a2 = (await api(w.psych, 'POST', '/assignments', { testId: draft.id, target: { kind: 'GRADES', grades: [7] }, ...openWindow(), consent: true })).json();
    expect(a2.testVersion).toBe(2);
    const audit = await t.prisma.schoolAuditLog.findMany({ where: { action: 'assessments.test.update' }, orderBy: { at: 'asc' } });
    expect(audit.map((x) => x.params)).toEqual([
      { version: 1, title: 'Sinov testi' },
      { version: 1, title: 'Yangi nom' },
      { version: 2, title: 'Yangi nom' },
      { version: 2, title: 'Uchinchi nom' },
    ]);
    expect(audit[2]).toMatchObject({ before: { version: 1 }, after: { version: 2 } });
  });

  it('shablon faqat o\'qish uchun; me\'yorlari o\'zgaradi (natija darhol qayta baholanadi) va tiklanadi', async () => {
    expect((await api(w.psych, 'PUT', '/tests/tpl-logic', sampleInput())).statusCode).toBe(409);
    const a = (await api(w.psych, 'POST', '/assignments', { testId: 'tpl-logic', target: { kind: 'CLASSES', classIds: [w.classes.c7a] }, ...openWindow(), consent: true })).json();
    const view = (await child(w.kids7a[0]!, 'GET', `/${a.id}`)).json();
    const answers = Object.fromEntries(view.items.slice(0, 10).map((it: { id: string; options: Array<{ key: string }> }) => [it.id, it.options[0]!.key]));
    expect((await child(w.kids7a[0]!, 'POST', `/${a.id}/submit`, { answers })).statusCode).toBe(201);
    const score = async () => (await api(w.psych, 'GET', '/tests/tpl-logic/results')).json().rows[0].scales[0];
    const before = await score();
    expect(before.standard).not.toBeNull();

    const norms = { total: [{ band: 'A13_14', mean: before.raw, sd: 2 }] };
    expect((await api(w.psych, 'PUT', '/tests/tpl-logic/norms', { norms })).statusCode).toBe(204);
    expect(await score()).toMatchObject({ raw: before.raw, z: 0, standard: 100, percentile: 50, band: 'AVERAGE' });
    expect((await api(w.psych, 'GET', '/tests/tpl-logic')).json()).toMatchObject({ readOnly: true, normsOverridden: true, norms });

    const sd0 = await api(w.psych, 'PUT', '/tests/tpl-logic/norms', { norms: { total: [{ band: 'A13_14', mean: 9, sd: 0 }] } });
    expect(sd0.json()).toMatchObject({ code: 'VALIDATION', message: 'total.0.sd: assessments.validation.sd' });
    const unknown = await api(w.psych, 'PUT', '/tests/tpl-logic/norms', { norms: { nope: [{ band: 'A13_14', mean: 9, sd: 1 }] } });
    expect(unknown.json().message).toBe('nope: assessments.validation.unknownScale');
    expect((await api(w.psych, 'PUT', '/tests/tpl-logic/norms', {})).json().message).toBe('norms: errors.form.required');

    expect((await api(w.psych, 'PUT', '/tests/tpl-logic/norms', { norms: null })).statusCode).toBe(204);
    expect((await api(w.psych, 'GET', '/tests/tpl-logic')).json().normsOverridden).toBe(false);
    expect(await score()).toEqual(before);
    const actions = (await t.prisma.schoolAuditLog.findMany({ where: { module: 'ASSESSMENTS', action: { startsWith: 'assessments.norms' } } })).map((x) => x.action);
    expect(actions.sort()).toEqual(['assessments.norms.restore', 'assessments.norms.update']);
  });

  it('nusxa, arxiv va qayta nashr; bo\'sh testni nashr qilib bo\'lmaydi', async () => {
    const copy = (await api(w.psych, 'POST', '/tests/tpl-emotion/duplicate')).json();
    expect(copy).toMatchObject({ source: 'CUSTOM', status: 'DRAFT', basedOn: 'tpl-emotion', version: 1 });
    expect(copy.items).toHaveLength(12);
    expect(copy.title).toEqual({ uz: 'Hissiy holat skriningi (nusxa)', ru: 'Скрининг эмоционального состояния (копия)' });

    const empty = (await api(w.psych, 'POST', '/tests', sampleInput({ items: [] }))).json();
    expect((await api(w.psych, 'POST', `/tests/${empty.id}/publish`)).json()).toMatchObject({ code: 'VALIDATION', message: 'items: assessments.validation.noItems' });
    expect((await api(w.psych, 'POST', '/tests/tpl-social/archive')).json().status).toBe('ARCHIVED');
    expect((await api(w.psych, 'GET', '/tests/tpl-social')).json()).toMatchObject({ status: 'ARCHIVED', readOnly: true });
    expect((await api(w.psych, 'POST', '/tests/tpl-social/archive')).statusCode).toBe(409);
    const assign = await api(w.psych, 'POST', '/assignments', { testId: 'tpl-social', target: { kind: 'GRADES', grades: [5] }, ...openWindow(), consent: true });
    expect(assign.statusCode).toBe(409);
    expect((await api(w.psych, 'POST', '/tests/tpl-social/publish')).json().status).toBe('PUBLISHED');
    const archivedOwn = (await api(w.psych, 'POST', `/tests/${copy.id}/archive`)).json();
    expect((await api(w.psych, 'PUT', `/tests/${archivedOwn.id}`, sampleInput())).statusCode).toBe(409);
  });

  it('tayinlash tekshiruvlari: rozilik, muddat, parallellar kesishmasi', async () => {
    const c8a = await createClass(t.prisma, w.schoolId, 8, 'A');
    const base = { testId: 'tpl-career', target: { kind: 'CLASSES', classIds: [w.classes.c7a] }, ...openWindow() };
    expect((await api(w.psych, 'POST', '/assignments', { ...base, consent: false })).json().message).toBe('consent: assessments.validation.consent');
    const window = openWindow();
    const reversed = await api(w.psych, 'POST', '/assignments', { ...base, consent: true, opensAt: window.closesAt, closesAt: window.opensAt });
    expect(reversed.json().message).toBe('closesAt: errors.form.endBeforeStart');
    expect((await api(w.psych, 'POST', '/assignments', { ...base, consent: true })).json().message).toBe('target: assessments.validation.noClasses');
    const ok = (await api(w.psych, 'POST', '/assignments', { ...base, target: { kind: 'GRADES', grades: [7, 8] }, consent: true })).json();
    expect(ok.classIds).toEqual([c8a.id]);
    expect(ok.opensAt).toBe(new Date(`${window.opensAt}:00+05:00`).toISOString());
    expect((await api(w.psych, 'POST', '/assignments', { ...base, testId: 'nope', consent: true })).statusCode).toBe(404);
  });

  it('bekor qilish: natija yo\'q — CANCELLED, bor — CLOSED; yopilgan tayinlash', async () => {
    const empty = (await api(w.psych, 'POST', '/assignments', { testId: 'tpl-social', target: { kind: 'CLASSES', classIds: [w.classes.c5a] }, ...openWindow(), consent: true })).json();
    expect((await api(w.psych, 'POST', `/assignments/${empty.id}/unassign`)).json().status).toBe('CANCELLED');
    expect((await api(w.psych, 'POST', `/assignments/${empty.id}/unassign`)).statusCode).toBe(409);
    const { assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    await child(w.kids7a[0]!, 'POST', `/${assignment.id}/submit`, { answers: ALL_A });
    expect((await api(w.psych, 'POST', `/assignments/${assignment.id}/unassign`)).json().status).toBe('CLOSED');
    const other = (await api(w.psych, 'POST', '/assignments', { testId: 'tpl-logic', target: { kind: 'GRADES', grades: [7] }, ...openWindow(), consent: true })).json();
    expect((await api(w.psych, 'POST', `/assignments/${other.id}/close`)).json().status).toBe('CLOSED');
    const rows = (await api(w.psych, 'GET', '/assignments')).json();
    const state = (id: string) => rows.find((r: { id: string }) => r.id === id)?.state;
    expect([state(empty.id), state(assignment.id), state(other.id)]).toEqual(['CANCELLED', 'ENDED', 'ENDED']);
    expect((await api(w.psych, 'POST', '/assignments/nope/close')).statusCode).toBe(404);
  });

  it('tenant izolyatsiyasi: boshqa maktab ID\'lari — 404, sinflari e\'tiborga olinmaydi', async () => {
    const { testId, assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    await child(w.kids7a[0]!, 'POST', `/${assignment.id}/submit`, { answers: ALL_A });
    const other = (await createSchool(t.prisma, 'other-school')).school;
    await createClass(t.prisma, other.id, 7, 'A');
    const foreign = await staffWith(t, other.id, 'PSYCHOLOGIST', 'psixolog2');
    for (const [method, url] of [
      ['GET', `/tests/${testId}`],
      ['PUT', `/tests/${testId}`],
      ['POST', `/tests/${testId}/publish`],
      ['POST', `/tests/${testId}/duplicate`],
      ['GET', `/tests/${testId}/export`],
      ['GET', `/tests/${testId}/results`],
      ['PUT', `/tests/${testId}/norms`],
      ['POST', `/assignments/${assignment.id}/close`],
      ['POST', `/assignments/${assignment.id}/unassign`],
    ] as const) {
      const res = await api(foreign, method, url, method === 'PUT' ? (url.endsWith('norms') ? { norms: null } : sampleInput()) : undefined);
      expect({ url, status: res.statusCode }).toEqual({ url, status: 404 });
    }
    expect((await api(foreign, 'GET', '/assignments')).json()).toEqual([]);
    expect((await api(foreign, 'GET', '/tests')).json().every((x: { source: string }) => x.source === 'TEMPLATE')).toBe(true);
    const crossClass = await api(foreign, 'POST', '/assignments', { testId: 'tpl-logic', target: { kind: 'CLASSES', classIds: [w.classes.c7a] }, ...openWindow(), consent: true });
    expect(crossClass.json().message).toBe('target: assessments.validation.noClasses');
    expect((await api(foreign, 'GET', '/tests/tpl-logic/results')).json()).toMatchObject({ rows: [], participation: { invited: 0, completed: 0 } });
    expect((await api(foreign, 'POST', '/assignments', { testId, target: { kind: 'GRADES', grades: [7] }, ...openWindow(), consent: true })).statusCode).toBe(404);

    // Rivojlanish bo'limi uchun umumiy o'qish: faqat shu maktab, javoblarsiz, o'qishda baholangan.
    const store = t.app.get(AssessmentsStore);
    expect(await store.scoredResults(other.id)).toEqual([]);
    const scored = await store.scoredResults(w.schoolId, { testId });
    expect(scored).toHaveLength(1);
    expect(scored[0]).toMatchObject({ studentId: w.kids7a[0]!.studentId, testId, version: 1, raw: { total: 4 }, scales: [{ key: 'total', standard: 130, band: 'VERY_HIGH' }] });
    expect(scored[0]).not.toHaveProperty('answersEnc');
    expect(await store.scoredResults(w.schoolId, { schoolId: other.id })).toHaveLength(1);
  });

  it('audit: modul ASSESSMENTS, o\'quvchi ismlari, ID\'lari va javoblar yo\'q', async () => {
    const { assignment } = await publishedAssignment(t, w, [w.classes.c7a]);
    for (const kid of w.kids7a) await child(kid, 'POST', `/${assignment.id}/submit`, { answers: ALL_A });
    await api(w.psych, 'POST', `/assignments/${assignment.id}/close`);
    const entries = await t.prisma.schoolAuditLog.findMany({ where: { module: 'ASSESSMENTS' } });
    expect(entries.map((e) => e.action).sort()).toEqual(['assessments.assign', 'assessments.assignment.close', 'assessments.test.create', 'assessments.test.publish']);
    expect(entries.find((e) => e.action === 'assessments.assign')).toMatchObject({ params: { classes: 1, count: 3, title: 'Sinov testi' }, entityId: assignment.id });
    expect(entries.find((e) => e.action === 'assessments.test.publish')).toMatchObject({ before: { status: 'DRAFT' }, after: { status: 'PUBLISHED' } });
    const json = JSON.stringify(entries);
    for (const kid of [...w.kids7a, ...w.kids7b]) expect(json).not.toContain(kid.studentId);
    expect(json).not.toMatch(/Alfa|0101/);
  });
});
