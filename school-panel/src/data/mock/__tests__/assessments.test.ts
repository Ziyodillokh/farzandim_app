import { beforeEach, describe, expect, it } from 'vitest';

import { getTables } from '../db';
import { assessmentsService as svc } from '../services/assessments';
import { L, sampleInput } from './assessments-fixtures';
import { freshDb, loginAs } from './helpers';

const WINDOW = { opensAt: '2026-10-12T08:00', closesAt: '2026-10-19T18:00' };

describe('Psixologik testlar — ruxsatlar', () => {
  beforeEach(freshDb);

  it.each(['DIRECTOR', 'ADMIN', 'HOMEROOM', 'DUTY'] as const)('%s kutubxona va tayinlashga kira olmaydi', async (role) => {
    loginAs(role);
    await expect(svc.listTests()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(svc.listAssignments()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(svc.assign({ testId: 'tpl-logic', target: { kind: 'CLASSES', classIds: ['cls-7a'] }, ...WINDOW, consent: true })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(svc.exportTest('tpl-logic')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(svc.previewResultsCsv('studentCode;test;date;raw\n')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('psixolog barcha testlarni ko\'radi (6 shablon)', async () => {
    loginAs('PSYCHOLOGIST');
    const tests = await svc.listTests();
    expect(tests.filter((t) => t.source === 'TEMPLATE')).toHaveLength(6);
    const logic = tests.find((t) => t.id === 'tpl-logic');
    expect(logic).toMatchObject({ itemCount: 16, assignmentsActive: 1 });
    expect(logic?.resultsCount).toBeGreaterThan(0);
  });

  it('direktor va navbatchi natijalarni ham ko\'rmaydi', async () => {
    for (const role of ['DIRECTOR', 'DUTY'] as const) {
      loginAs(role);
      await expect(svc.resultsByTest('tpl-logic')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    }
  });

  it('sinf rahbari: o\'z sinfi — faqat darajalar; boshqa sinf — FORBIDDEN', async () => {
    loginAs('HOMEROOM');
    await expect(svc.resultsByTest('tpl-logic', { classId: 'cls-7b' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    const res = await svc.resultsByTest('tpl-logic');
    expect(res.bandsOnly).toBe(true);
    expect(res.rows.length).toBeGreaterThan(0);
    for (const row of res.rows) {
      expect(row.classId).toBe('cls-7a');
      expect(row.answers).toBeUndefined();
      expect(row.durationSec).toBeUndefined();
      for (const s of row.scales) expect(Object.keys(s).sort()).toEqual(['band', 'key']);
    }
    const own = await svc.resultsByTest('tpl-logic', { classId: 'cls-7a' });
    expect(own.rows.length).toBe(res.rows.length);
  });
});

describe('Psixologik testlar — to\'liq oqim', () => {
  beforeEach(() => {
    freshDb();
    loginAs('PSYCHOLOGIST');
  });

  it('yaratish → nashr → tayinlash → simulyatsiya → natijalar', async () => {
    const draft = await svc.createTest(sampleInput());
    expect(draft).toMatchObject({ source: 'CUSTOM', status: 'DRAFT', version: 1 });
    await expect(svc.assign({ testId: draft.id, target: { kind: 'CLASSES', classIds: ['cls-7a'] }, ...WINDOW, consent: true })).rejects.toMatchObject({ code: 'CONFLICT' });
    await svc.publishTest(draft.id);
    const a = await svc.assign({ testId: draft.id, target: { kind: 'CLASSES', classIds: ['cls-7a', 'cls-1a'] }, ...WINDOW, consent: true });
    expect(a.classIds).toEqual(['cls-7a']);
    expect(a.invited).toBeGreaterThan(20);
    const sim = await svc.simulateCompletion(a.id);
    expect(sim.created).toBe(Math.ceil(a.invited * 0.8));
    const res = await svc.resultsByTest(draft.id, { assignmentId: a.id });
    expect(res.rows).toHaveLength(sim.created);
    expect(res.participation).toEqual({ invited: a.invited, completed: sim.created });
    expect(res.rows[0]?.answers).toHaveLength(4);
    expect(res.distribution.reduce((s, b) => s + b.count, 0)).toBe(sim.created);
    const rows = await svc.listAssignments({ testId: draft.id });
    expect(rows[0]).toMatchObject({ state: 'ACTIVE', completed: sim.created });
    const notification = getTables().notifications.find((n) => n.id === `ntf-test-${a.id}-2026-10-12`);
    expect(notification).toMatchObject({ kind: 'TEST_COMPLETED', roles: ['PSYCHOLOGIST'], classIds: null, params: { count: sim.created } });
  });

  it('nashr etilgan testda savol o\'zgarsa versiya oshadi, faqat nom o\'zgarsa — yo\'q', async () => {
    const draft = await svc.createTest(sampleInput());
    const sameDraft = await svc.updateTest(draft.id, sampleInput({ items: sampleInput().items.slice(0, 3) }));
    expect(sameDraft.version).toBe(1);
    await svc.publishTest(draft.id);
    const renamed = await svc.updateTest(draft.id, sampleInput({ title: L('Yangi nom'), items: sampleInput().items.slice(0, 3) }));
    expect(renamed.version).toBe(1);
    const bumped = await svc.updateTest(draft.id, sampleInput({ title: L('Yangi nom') }));
    expect(bumped.version).toBe(2);
    expect(bumped.status).toBe('PUBLISHED');
  });

  it('shablonni tahrirlab bo\'lmaydi; me\'yorlari o\'zgaradi va tiklanadi', async () => {
    await expect(svc.updateTest('tpl-logic', sampleInput())).rejects.toMatchObject({ code: 'CONFLICT' });
    await svc.updateNorms('tpl-logic', { total: [{ band: 'A13_14', mean: 9, sd: 2 }] });
    expect(await svc.getTest('tpl-logic')).toMatchObject({ readOnly: true, normsOverridden: true });
    await expect(svc.updateNorms('tpl-logic', { total: [{ band: 'A13_14', mean: 9, sd: 0 }] })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(svc.updateNorms('tpl-logic', { nope: [{ band: 'A13_14', mean: 9, sd: 1 }] })).rejects.toMatchObject({ code: 'VALIDATION' });
    await svc.updateNorms('tpl-logic', null);
    expect(await svc.getTest('tpl-logic')).toMatchObject({ normsOverridden: false });
  });

  it('nusxa — CUSTOM qoralama, basedOn bilan', async () => {
    const copy = await svc.duplicateTest('tpl-emotion');
    expect(copy).toMatchObject({ source: 'CUSTOM', status: 'DRAFT', basedOn: 'tpl-emotion', version: 1 });
    expect(copy.items).toHaveLength(12);
    expect(copy.title.uz).toContain('(nusxa)');
  });

  it('arxiv va qayta nashr; bo\'sh testni nashr qilib bo\'lmaydi', async () => {
    const empty = await svc.createTest(sampleInput({ items: [] }));
    await expect(svc.publishTest(empty.id)).rejects.toMatchObject({ code: 'VALIDATION' });
    await svc.archiveTest('tpl-social');
    expect((await svc.getTest('tpl-social')).status).toBe('ARCHIVED');
    await expect(svc.assign({ testId: 'tpl-social', target: { kind: 'GRADES', grades: [5] }, ...WINDOW, consent: true })).rejects.toMatchObject({ code: 'CONFLICT' });
    await svc.publishTest('tpl-social');
    expect((await svc.getTest('tpl-social')).status).toBe('PUBLISHED');
  });

  it('tayinlash tekshiruvlari: rozilik, muddat, parallellar kesishmasi', async () => {
    const base = { testId: 'tpl-career', target: { kind: 'CLASSES' as const, classIds: ['cls-7a'] }, ...WINDOW };
    await expect(svc.assign({ ...base, consent: false as unknown as true })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(svc.assign({ ...base, consent: true, closesAt: '2026-10-11T08:00' })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(svc.assign({ ...base, consent: true })).rejects.toMatchObject({ code: 'VALIDATION' });
    const ok = await svc.assign({ ...base, target: { kind: 'GRADES', grades: [7, 8] }, consent: true });
    expect(ok.classIds.sort()).toEqual(['cls-8a', 'cls-8b']);
  });

  it('bekor qilish: natija yo\'q — CANCELLED, bor — CLOSED', async () => {
    const empty = await svc.assign({ testId: 'tpl-social', target: { kind: 'CLASSES', classIds: ['cls-5a'] }, ...WINDOW, consent: true });
    expect((await svc.unassign(empty.id)).status).toBe('CANCELLED');
    await expect(svc.unassign(empty.id)).rejects.toMatchObject({ code: 'CONFLICT' });
    expect((await svc.unassign('pa-1')).status).toBe('CLOSED');
    const rows = await svc.listAssignments();
    expect(rows.find((r) => r.id === 'pa-1')?.state).toBe('ENDED');
    expect(rows.find((r) => r.id === empty.id)?.state).toBe('CANCELLED');
    await expect(svc.simulateCompletion('pa-1')).rejects.toMatchObject({ code: 'CONFLICT' });
    await expect(svc.simulateCompletion('pa-3')).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('audit: modul ASSESSMENTS, o\'quvchi ismlari va javoblar yo\'q', async () => {
    const draft = await svc.createTest(sampleInput());
    await svc.publishTest(draft.id);
    const a = await svc.assign({ testId: draft.id, target: { kind: 'CLASSES', classIds: ['cls-7a'] }, ...WINDOW, consent: true });
    await svc.simulateCompletion(a.id);
    await svc.importResultsCsv(`studentCode;test;date;raw\n${getTables().students[0]?.studentCode};Qog'oz test;2026-10-01;42`);
    const t = getTables();
    const entries = t.audit.filter((e) => e.module === 'ASSESSMENTS');
    expect(entries.map((e) => e.action)).toEqual(
      expect.arrayContaining(['assessments.test.create', 'assessments.test.publish', 'assessments.assign', 'assessments.simulate', 'assessments.results.import']),
    );
    const json = JSON.stringify(entries);
    for (const s of t.students) {
      expect(json).not.toContain(`${s.lastName} ${s.firstName}`);
      expect(json).not.toContain(`"${s.id}"`);
    }
    for (const r of t.psychResults.filter((x) => x.answers)) expect(json).not.toContain(r.answers);
  });
});
