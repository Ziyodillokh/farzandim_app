// Rivojlanish: ruxsatlar (har rol), sinf rahbari — o'z sinfi, psixolog — to'liq profil,
// sinf rahbari — xom ballsiz / javoblarsiz, direktor — faqat K=5 agregatlar (ism / ID yo'q),
// e'tibor ro'yxati va choraklar tanlovi.

import { addDays, tashkentDay } from '../../src/common/time/tashkent';
import { termOf } from '../../src/school/assessments/psych/terms';
import { resetDb } from './db';
import { buildDevWorld, DAY_MS, devApi, DevWorld, seedBatch } from './school-development-fixtures';
import { createTestApp, TestApp } from './test-app';

const termAt = (at: Date) => termOf(tashkentDay(at)).key;

describe('School development — ruxsatlar va ko\'rinish', () => {
  let t: TestApp;
  let w: DevWorld;
  let api: ReturnType<typeof devApi>;
  const now = new Date(Date.now() - 60_000);
  const prev = new Date(Date.now() - 200 * DAY_MS);

  /** Ikki chorak: mantiq + hissiy holat (7-A, 7-B, 8-A — bitta partiyada), 7-A uchun kasbiy qiziqish. */
  async function seedTerms() {
    const all = [...w.pupils7a, ...w.pupils7b, ...w.pupils8a];
    for (const at of [prev, now]) {
      await seedBatch(t, w, { testId: 'tpl-logic', at, pupils: all, raw: (i) => ({ total: i === 0 && at === now ? 1 : 6 + (i % 8) }) });
      await seedBatch(t, w, { testId: 'tpl-emotion', at: new Date(at.getTime() + 5000), pupils: all, raw: (i) => ({ worry: 10 + (i % 15), mood: 14 + (i % 9) }) });
    }
    await seedBatch(t, w, { testId: 'tpl-career', at: new Date(now.getTime() + 9000), pupils: w.pupils7a, raw: () => ({ R: 2, I: 5, A: 4, S: 1, E: 0, C: 3 }) });
  }

  beforeAll(async () => {
    t = await createTestApp();
    api = devApi(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await buildDevWorld(t);
  });

  afterAll(() => t.close());

  it('ruxsatlar matritsasi: har rol uchun har marshrut', async () => {
    await seedTerms();
    const kid = w.pupils7a[0]!.id;
    const other = w.pupils7b[0]!.id;
    const status = async (who: keyof DevWorld, url: string) => (await api(w[who] as never, url)).statusCode;
    const routes = [
      `/students/${kid}/profile`,
      `/classes/${w.classes.c7a}/overview`,
      '/school/overview',
      '/attention',
      '/class-options',
      '/term-options',
    ];
    const matrix: Record<string, number[]> = {
      psych: [200, 200, 200, 200, 200, 200],
      homeroom: [200, 200, 403, 403, 200, 200],
      director: [403, 403, 200, 403, 403, 200],
      admin: [403, 403, 200, 403, 403, 200],
      duty: [403, 403, 403, 403, 403, 403],
      teacher: [403, 403, 403, 403, 403, 403],
    };
    for (const [role, expected] of Object.entries(matrix)) {
      const got = await Promise.all(routes.map((r) => status(role as keyof DevWorld, r)));
      expect({ role, got }).toEqual({ role, got: expected });
    }
    expect(await status('homeroom', `/students/${other}/profile`)).toBe(403);
    expect(await status('homeroom', `/classes/${w.classes.c7b}/overview`)).toBe(403);
    expect(await status('psych', '/students/nope/profile')).toBe(404);
    expect(await status('psych', '/classes/nope/overview')).toBe(404);
    expect(await status('psych', `/classes/${w.classes.c7a}/overview?termKey=2019-20:Q9`)).toBe(400);
    expect((await api(w.director, '/school/overview?termKey=bad')).json()).toMatchObject({ code: 'VALIDATION', message: 'termKey: errors.form.invalidDate' });
  });

  it('psixolog: to\'liq profil — xom ball, javoblar, vaqt, hissiy indeks, kasbiy qiziqish', async () => {
    await seedTerms();
    const p = (await api(w.psych, `/students/${w.pupils7a[0]!.id}/profile`)).json();
    expect(p).toMatchObject({ canSeeRaw: true, student: { name: 'Alfaov Alfa0', className: '7-A', grade: 7, ageBand: 'A13_14' } });
    expect(p.context).toEqual({ attendance30: null, classLearning: { activeRate: 0, avgScore: null, suppressed: false } });
    expect(p.results).toHaveLength(5);
    expect(p.results[0]).toMatchObject({ testId: 'tpl-career', answers: '0123', durationSec: 200, raw: { I: 5 }, testTitle: { uz: 'Kasbiy qiziqishlar' } });
    expect(p.latest.find((d: { domain: string }) => d.domain === 'EMOTIONAL').index).not.toBeNull();
    expect(p.timeline.map((x: { termKey: string }) => x.termKey)).toEqual([termAt(prev), termAt(now)]);
    expect(p.timeline[1].values.EMOTIONAL).toEqual(expect.any(Number));
    expect(p.career).toEqual({ topCodes: 'IAC', raw: { R: 2, I: 5, A: 4, S: 1, E: 0, C: 3 }, takenAt: expect.any(String) });
    expect(Object.keys(p.classAverage).length).toBeGreaterThan(0);
  });

  it('sinf rahbari: o\'z sinfi — xom ball, javoblar va vaqt yo\'q, hissiy holat faqat daraja; davomat bor', async () => {
    await seedTerms();
    await t.prisma.schoolShift.updateMany({ where: { schoolId: w.schoolId }, data: { weekdays: [1, 2, 3, 4, 5, 6, 7] } });
    const kid = w.pupils7a[1]!;
    const day = (n: number) => addDays(tashkentDay(), -n);
    await t.prisma.schoolAttendance.createMany({
      data: (['PRESENT', 'LATE', 'ABSENT'] as const).map((status, i) => ({ schoolId: w.schoolId, studentId: kid.id, classId: kid.classId, date: day(i + 1), status, source: 'MANUAL' as const })),
    });
    const res = await api(w.homeroom, `/students/${kid.id}/profile`);
    const p = res.json();
    expect(p.canSeeRaw).toBe(false);
    expect(p.context.attendance30).toEqual({ rate: 67, late: 1, absent: 1 });
    const emotional = p.latest.find((d: { domain: string }) => d.domain === 'EMOTIONAL');
    expect(emotional.index).toBeNull();
    expect(emotional.band).not.toBeNull();
    // Sinfdoshlar va sinf o'rtachasini ayirib yashirin hissiy indeks tiklanmasin.
    expect(p.classAverage.EMOTIONAL).toBeUndefined();
    expect(p.classAverage.REASONING).toEqual(expect.any(Number));
    expect(p.timeline.every((x: { values: Record<string, number> }) => x.values.EMOTIONAL === undefined)).toBe(true);
    expect(p.career).toMatchObject({ topCodes: 'IAC', raw: {} });
    for (const r of p.results) {
      expect(r.answers).toBeUndefined();
      expect(r.durationSec).toBeUndefined();
      expect(r.raw).toEqual({});
      for (const s of r.scales) expect([s.raw, s.max]).toEqual([0, null]);
    }
    const emotionResult = p.results.find((r: { testId: string }) => r.testId === 'tpl-emotion');
    expect(emotionResult.scales.every((s: { standard: unknown; percentile: unknown; band: unknown }) => s.standard === null && s.percentile === null && s.band !== null)).toBe(true);
    expect(res.body).not.toContain('0123');
  });

  it('sinf ko\'rinishi: sinf rahbari — e\'tibor belgisisiz, hissiy indekssiz; psixolog — e\'tibor belgisi bilan', async () => {
    await seedTerms();
    const own = (await api(w.homeroom, `/classes/${w.classes.c7a}/overview`)).json();
    expect(own).toMatchObject({ className: '7-A', termKey: termAt(now), assessed: 6, total: 6 });
    expect(own.rows.every((r: { attention: boolean; domains: { EMOTIONAL?: { index: unknown } } }) => !r.attention && (r.domains.EMOTIONAL?.index ?? null) === null)).toBe(true);
    expect(own.domainAverages.find((d: { domain: string }) => d.domain === 'REASONING').index).toEqual(expect.any(Number));
    expect(own.domainAverages.find((d: { domain: string }) => d.domain === 'EMOTIONAL').index).toBeNull();
    // Bosh sahifa kartasi (jonli o'rtacha) ham hissiy indekssiz.
    const card = (await t.app.inject({ method: 'GET', url: '/api/school/dashboard/overview', headers: { authorization: `Bearer ${w.homeroom.token}` } })).json().development;
    expect(card).toMatchObject({ mode: 'CLASS', className: '7-A' });
    expect(card.domains.find((d: { domain: string }) => d.domain === 'EMOTIONAL').index).toBeNull();
    expect(card.domains.find((d: { domain: string }) => d.domain === 'REASONING').index).toEqual(expect.any(Number));
    expect(Object.keys(own.schoolAverages)).toEqual(expect.arrayContaining(['REASONING', 'EMOTIONAL']));
    const past = (await api(w.homeroom, `/classes/${w.classes.c7a}/overview?termKey=${encodeURIComponent(termAt(prev))}`)).json();
    expect(past.termKey).toBe(termAt(prev));

    const full = (await api(w.psych, `/classes/${w.classes.c7a}/overview`)).json();
    const flagged = full.rows.find((r: { studentId: string }) => r.studentId === w.pupils7a[0]!.id);
    expect(flagged.attention).toBe(true);
    expect(flagged.domains.EMOTIONAL.index).toEqual(expect.any(Number));
    expect(full.domainAverages.find((d: { domain: string }) => d.domain === 'EMOTIONAL').index).toEqual(expect.any(Number));
  });

  it('e\'tibor ro\'yxati — faqat psixolog; sinf tanlovi va choraklar rolga mos', async () => {
    await seedTerms();
    const rows = (await api(w.psych, '/attention')).json();
    expect(rows[0]).toMatchObject({ studentId: w.pupils7a[0]!.id, name: 'Alfaov Alfa0', className: '7-A', reasons: expect.arrayContaining(['COG_LOW']) });
    expect((await api(w.psych, '/class-options')).json().map((c: { name: string }) => c.name)).toEqual(['7-A', '7-B', '8-A']);
    expect((await api(w.homeroom, '/class-options')).json()).toEqual([{ id: w.classes.c7a, name: '7-A', grade: 7 }]);
    expect((await api(w.psych, '/term-options')).json()).toEqual([
      { key: termAt(now), n: 15 },
      { key: termAt(prev), n: 15 },
    ]);
    expect((await api(w.director, '/term-options')).json()).toEqual([
      { key: termAt(now), n: 12 },
      { key: termAt(prev), n: 12 },
    ]);
    expect((await api(w.homeroom, '/term-options')).json()).toEqual([
      { key: termAt(now), n: 6 },
      { key: termAt(prev), n: 6 },
    ]);
  });

  it('direktor: K=5 — 3 kishilik 8-A e\'lon qilinmaydi, natijada ism va ID yo\'q', async () => {
    await seedTerms();
    const o = (await api(w.director, `/school/overview?termKey=${encodeURIComponent(termAt(now))}`)).json();
    expect(o).toMatchObject({ suppressed: true, participation: { assessed: 12, eligible: 15, rate: 80 }, attentionCount: '<5' });
    const row = (id: string) => o.heat.find((h: { classId: string }) => h.classId === id);
    expect(row(w.classes.c8a)).toMatchObject({ n: 0, hidden: false });
    expect(Object.values(row(w.classes.c8a).cells).every((v) => v === null)).toBe(true);
    expect(row(w.classes.c7a)).toMatchObject({ n: 6, hidden: false });
    expect(o.cognitiveByGrade.every((g: { bands: unknown }) => g.bands === null)).toBe(true);
    expect(o.cognitiveByGrade.map((g: { grade: number; n: number }) => [g.grade, g.n])).toEqual([[7, 12]]);

    const psych = (await api(w.psych, `/school/overview?termKey=${encodeURIComponent(termAt(now))}`)).json();
    expect(psych).toMatchObject({ suppressed: false, participation: { assessed: 15 } });
    expect(psych.heat.find((h: { classId: string }) => h.classId === w.classes.c8a)).toMatchObject({ n: 3, hidden: false });

    const json = JSON.stringify([o, (await api(w.director, '/school/overview')).json(), (await api(w.director, '/term-options')).json()]);
    for (const p of [...w.pupils7a, ...w.pupils7b, ...w.pupils8a]) {
      expect(json).not.toContain(p.id);
      expect(json).not.toContain(p.name);
    }
    expect(json).not.toMatch(/Alfa|Beta|Gamma/);
  });
});
