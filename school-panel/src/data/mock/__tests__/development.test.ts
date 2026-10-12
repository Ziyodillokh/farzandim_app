import { beforeEach, describe, expect, it } from 'vitest';

import type { RoleKey } from '@/data/contracts';
import { getTables } from '../db';
import { currentActor } from '../context';
import { developmentService as dev } from '../services/development';
import { devIndex } from '../services/development-aggregate';
import { developmentSummary } from '../services/development-summary';
import { freshDb, loginAs } from './helpers';

type Role = Exclude<RoleKey, 'TEACHER'>;

/** Tarixli (4-sinf va undan yuqori) o'quvchi: shu sinfdan. */
function studentOf(classId: string): string {
  const t = getTables();
  const idx = devIndex(t);
  const s = t.students.find((x) => !x.archived && x.classId === classId && (idx.byStudent.get(x.id)?.length ?? 0) > 3);
  if (!s) throw new Error(classId);
  return s.id;
}

async function rejects(fn: () => Promise<unknown>, code = 'FORBIDDEN'): Promise<void> {
  await expect(fn()).rejects.toMatchObject({ code });
}

describe('Rivojlanish — o\'quvchi profili (ruxsatlar)', () => {
  beforeEach(() => freshDb());

  it('psixolog istalgan o\'quvchini ko\'radi (javoblar va xom ball bilan)', async () => {
    loginAs('PSYCHOLOGIST');
    const p = await dev.studentProfile(studentOf('cls-10b'));
    expect(p.canSeeRaw).toBe(true);
    expect(p.student.className).toBe('10-B');
    expect(p.latest.find((d) => d.domain === 'EMOTIONAL')?.index).not.toBeNull();
    expect(p.results.length).toBeGreaterThan(3);
    expect(p.results.some((r) => Object.keys(r.raw).length > 0)).toBe(true);
    expect(p.context.attendance30).toBeNull();
    expect(p.timeline.length).toBeGreaterThanOrEqual(2);
    expect(p.career).not.toBeNull();
  });

  it("sinf rahbari: o'z sinfi — javoblarsiz, xom ballarsiz, hissiy holat faqat daraja; davomat bor", async () => {
    loginAs('HOMEROOM');
    const p = await dev.studentProfile(studentOf('cls-7a'));
    expect(p.canSeeRaw).toBe(false);
    const emotional = p.latest.find((d) => d.domain === 'EMOTIONAL');
    expect(emotional?.index).toBeNull();
    expect(emotional?.band).not.toBeNull();
    expect(p.results.every((r) => r.answers === undefined && Object.keys(r.raw).length === 0)).toBe(true);
    expect(p.results.flatMap((r) => r.scales).every((s) => s.raw === 0 && s.max === null)).toBe(true);
    expect(p.timeline.every((x) => x.values.EMOTIONAL === undefined)).toBe(true);
    expect(p.context.attendance30).not.toBeNull();
    expect(p.context.attendance30?.rate).toBeGreaterThan(50);
    expect(Object.keys(p.classAverage).length).toBeGreaterThan(0);
  });

  it("sinf rahbari boshqa sinf o'quvchisini ko'ra olmaydi (8-B → FORBIDDEN)", async () => {
    loginAs('HOMEROOM');
    await rejects(() => dev.studentProfile(studentOf('cls-8b')));
    await rejects(() => dev.classOverview('cls-8b'));
  });

  it.each<Role>(['DIRECTOR', 'ADMIN', 'DUTY'])('%s: shaxsiy profil va sinf ro\'yxati — FORBIDDEN', async (role) => {
    loginAs(role);
    await rejects(() => dev.studentProfile(studentOf('cls-7a')));
    await rejects(() => dev.classOverview('cls-7a'));
    await rejects(() => dev.attentionList());
  });

  it("noma'lum o'quvchi — NOT_FOUND, noto'g'ri chorak — VALIDATION", async () => {
    loginAs('PSYCHOLOGIST');
    await rejects(() => dev.studentProfile('stu-nope'), 'NOT_FOUND');
    await rejects(() => dev.classOverview('cls-7a', '2019-20:Q9'), 'VALIDATION');
    await rejects(() => dev.schoolOverview({ termKey: 'bad' }), 'VALIDATION');
  });
});

describe('Rivojlanish — sinf va maktab kesimi', () => {
  beforeEach(() => freshDb());

  it("sinf rahbari: 7-A ro'yxati, hissiy indeks yo'q, e'tibor belgisi yo'q", async () => {
    loginAs('HOMEROOM');
    const c = await dev.classOverview('cls-7a');
    expect(c.className).toBe('7-A');
    expect(c.total).toBeGreaterThan(10);
    expect(c.assessed).toBeGreaterThan(c.total / 2);
    expect(c.rows.every((r) => !r.attention && (r.domains.EMOTIONAL?.index ?? null) === null)).toBe(true);
    expect(Object.keys(c.schoolAverages).length).toBeGreaterThan(0);
    const past = await dev.classOverview('cls-7a', '2025-26:Q4');
    expect(past.termKey).toBe('2025-26:Q4');
    expect(past.domainAverages.filter((d) => d.index !== null).length).toBeGreaterThanOrEqual(4);
    expect(Object.keys(past.schoolAverages).length).toBeGreaterThanOrEqual(4);
  });

  it("sinf rahbari maktab kesimini ko'ra olmaydi; navbatchida ruxsat yo'q", async () => {
    loginAs('HOMEROOM');
    await rejects(() => dev.schoolOverview());
    loginAs('DUTY');
    await rejects(() => dev.schoolOverview());
    await rejects(() => dev.termOptions());
  });

  it("psixolog: to'liq (yashirilmagan) kesim, darajalar parallel bo'yicha", async () => {
    loginAs('PSYCHOLOGIST');
    const o = await dev.schoolOverview();
    expect(o.suppressed).toBe(false);
    expect(o.cognitiveByGrade.every((g) => g.bands !== null && !g.hidden)).toBe(true);
    expect(Number(o.attentionCount)).toBeGreaterThan(0);
    expect(o.trend.length).toBe(devIndex(getTables()).terms.length);
  });

  it("direktor: yashirilgan, parallel darajalari yo'q, qo'pol taqsimot faqat ildizda", async () => {
    loginAs('DIRECTOR');
    const o = await dev.schoolOverview();
    expect(o.suppressed).toBe(true);
    expect(o.cognitiveByGrade.every((g) => g.bands === null)).toBe(true);
    expect(o.cognitiveCoarse).not.toBeNull();
    expect(o.participation.rate).toBeGreaterThan(70);
    expect(o.domainAverages.find((d) => d.domain === 'REASONING')?.index).toBeGreaterThan(40);
    const options = await dev.termOptions();
    expect(options.map((x) => x.key)).toContain(o.termKey);
  });

  it("e'tibor ro'yxati: faqat psixolog, faol o'quvchilarning 3–9%", async () => {
    loginAs('PSYCHOLOGIST');
    const rows = await dev.attentionList();
    const active = getTables().students.filter((s) => !s.archived).length;
    const rate = rows.length / active;
    expect(rate, `${rows.length}/${active}`).toBeGreaterThanOrEqual(0.03);
    expect(rate, `${rows.length}/${active}`).toBeLessThanOrEqual(0.09);
    expect(rows.every((r) => r.reasons.length > 0)).toBe(true);
    const c = await dev.classOverview(rows[0]!.classId);
    expect(c.rows.find((r) => r.studentId === rows[0]!.studentId)?.attention).toBe(true);
  });
});

describe('developmentSummary (bosh sahifa)', () => {
  beforeEach(() => freshDb());
  const today = '2026-10-12';

  it.each<[Role, string | null]>([
    ['DIRECTOR', 'AGGREGATE'],
    ['ADMIN', 'AGGREGATE'],
    ['HOMEROOM', 'CLASS'],
    ['PSYCHOLOGIST', 'PSYCHOLOGIST'],
    ['DUTY', null],
  ])('%s → %s', (role, mode) => {
    loginAs(role);
    const s = developmentSummary(getTables(), currentActor(), today);
    expect(s?.mode ?? null).toBe(mode);
    if (s?.mode === 'CLASS') expect(s.classId).toBe('cls-7a');
    if (s?.mode === 'PSYCHOLOGIST') expect(s.attention).toBeGreaterThan(0);
    if (s?.mode === 'AGGREGATE') expect(JSON.stringify(s)).not.toMatch(/stu-/);
  });
});
