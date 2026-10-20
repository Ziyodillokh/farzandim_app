import { beforeEach, describe, expect, it } from 'vitest';

import type { CareResponse, RoleKey } from '@/data/contracts';
import { CARE_MIN_GROUP } from '@/lib/k-anon';
import { percent } from '@/lib/utils';
import { simulateSurveyResponses, SIM_PARTICIPATION } from '../care-sim';
import { clockNow } from '../clock';
import { currentActor } from '../context';
import { getTables, transact } from '../db';
import { activeSafetySignals, notificationsFor } from '../notify';
import { careService } from '../services/care';
import { defaultSurvey } from '../services/care-aggregate';
import { dashboardService, type DashboardAlertKind } from '../services/dashboard';
import { parentsService } from '../services/parents';
import { reportsService } from '../services/reports';
import { guardiansService } from '../services/students';
import { simulate } from '../simulator';
import type { Tables } from '../tables';
import { freshDb, loginAs } from './helpers';

const TODAY = '2026-10-12';
const URGENT_NEW = 'care-1';

async function alertKinds(): Promise<DashboardAlertKind[]> {
  return (await dashboardService.overview()).alerts.map((a) => a.kind);
}

/** Psixolog yangi (javobsiz) so'rovnoma yaratib faollashtiradi. */
async function activateFreshSurvey(weekStart = '2026-10-19'): Promise<string> {
  loginAs('PSYCHOLOGIST');
  const draft = await careService.createSurvey({ title: 'Yangi', weekStart, ageGroups: ['G5_8', 'G9_11'], questionIds: ['q-1', 'q-5', 'q-8'] });
  await careService.activateSurvey(draft.id);
  return draft.id;
}

describe('H6: himoya protokoli xavfsizlik signalini yuboradi', () => {
  beforeEach(freshDb);

  it('signal bo\'sh params bilan yaratiladi, ism/sinf/matn yo\'q', async () => {
    loginAs('PSYCHOLOGIST');
    const request = getTables().careRequests.find((r) => r.id === URGENT_NEW);
    await careService.activateProtocol(URGENT_NEW);
    const signal = getTables().notifications?.find((n) => n.id === `ntf-safety-${URGENT_NEW}`);
    expect(signal).toMatchObject({ kind: 'SAFETY_SIGNAL', roles: ['DIRECTOR', 'DUTY'], classIds: null, params: {}, subject: null, href: null });
    const raw = JSON.stringify(signal);
    expect(raw).not.toContain(request?.studentId ?? '?');
    expect(raw).not.toContain(request?.classId ?? '?');
    expect(Date.parse(signal?.at ?? '')).toBeLessThanOrEqual(clockNow().getTime());
  });

  it('direktor va navbatchi ko\'radi, admin va psixolog ko\'rmaydi', async () => {
    loginAs('DIRECTOR');
    expect(await alertKinds()).not.toContain('SAFETY_SIGNAL');
    loginAs('PSYCHOLOGIST');
    await careService.activateProtocol(URGENT_NEW);

    loginAs('DIRECTOR');
    const director = (await dashboardService.overview()).alerts.find((a) => a.kind === 'SAFETY_SIGNAL');
    expect(director).toMatchObject({ count: 1, href: '/care', tone: 'destructive' });
    loginAs('DUTY');
    const duty = (await dashboardService.overview()).alerts.find((a) => a.kind === 'SAFETY_SIGNAL');
    expect(duty).toMatchObject({ count: 1, href: '/attendance' });
    expect(activeSafetySignals(getTables(), currentActor(), clockNow().getTime())).toBe(1);

    for (const role of ['ADMIN', 'PSYCHOLOGIST', 'HOMEROOM'] as const) {
      loginAs(role);
      expect(await alertKinds()).not.toContain('SAFETY_SIGNAL');
      expect(notificationsFor(getTables(), currentActor()).some((n) => n.kind === 'SAFETY_SIGNAL')).toBe(false);
    }
  });

  it('protokol ikkinchi marta ishga tushmaydi — signal takrorlanmaydi', async () => {
    loginAs('PSYCHOLOGIST');
    await careService.activateProtocol(URGENT_NEW);
    await expect(careService.activateProtocol(URGENT_NEW)).rejects.toMatchObject({ code: 'CONFLICT' });
    expect(getTables().notifications?.filter((n) => n.id === `ntf-safety-${URGENT_NEW}`)).toHaveLength(1);
  });
});

describe('H7: yangi so\'rovnoma direktor ko\'rinishini bo\'shatmaydi', () => {
  beforeEach(freshDb);

  it('faollashtirish activatedAt ni yozadi', async () => {
    const id = await activateFreshSurvey();
    expect(getTables().careSurveys.find((s) => s.id === id)?.activatedAt).toMatch(/^2026-10-12T\d{2}:\d{2}:\d{2}$/);
  });

  it('0 javobli faol so\'rovnoma — natija oldingi tayyor so\'rovnomadan', async () => {
    const id = await activateFreshSurvey();
    loginAs('DIRECTOR');
    const agg = await careService.aggregate({ breakdown: 'SCHOOL' });
    expect(agg.surveyId).not.toBe(id);
    expect(agg.respondents).toBeGreaterThanOrEqual(CARE_MIN_GROUP);
    expect(Object.keys(agg.overall).length).toBeGreaterThan(0);

    const options = await careService.surveyOptions();
    expect(options.find((o) => o.id === id)?.ready).toBe(false);
    expect(options.find((o) => o.id === agg.surveyId)?.ready).toBe(true);

    const overview = await dashboardService.overview();
    expect(overview.care?.wellbeing).not.toBeNull();
    expect(overview.care?.participation).toBeGreaterThan(0);
    const report = await reportsService.monthly('2026-10');
    expect(report.care?.wellbeing).not.toBeNull();
  });

  it('tayyor so\'rovnoma bo\'lmasa — eng so\'nggisiga qaytadi', () => {
    transact((t) => {
      t.careResponses = [];
    });
    const latest = [...getTables().careSurveys].sort((a, b) => b.weekStart.localeCompare(a.weekStart))[0];
    expect(defaultSurvey(getTables())?.id).toBe(latest?.id);
  });
});

describe('H1: direktor so\'rovnomalar ro\'yxatini ko\'radi', () => {
  beforeEach(freshDb);

  it('sarlavha, hafta, mavzular; ishtirok faqat k ≥ 5; savol matni yo\'q', async () => {
    const id = await activateFreshSurvey();
    loginAs('DIRECTOR');
    const list = await careService.surveySummaries();
    const fresh = list.find((s) => s.id === id);
    expect(fresh).toMatchObject({ status: 'ACTIVE', questionCount: 3, participation: null });
    expect(fresh?.topics).toEqual(['WELLBEING', 'PEERS', 'SAFETY']);
    const ready = list.find((s) => s.participation !== null);
    expect(ready?.participation?.respondents).toBeGreaterThanOrEqual(CARE_MIN_GROUP);
    const raw = JSON.stringify(list);
    for (const forbidden of ['questionIds', 'studentId', 'answers', 'text']) expect(raw).not.toContain(`"${forbidden}"`);
    loginAs('ADMIN');
    expect((await careService.surveySummaries()).length).toBe(list.length);
  });

  it('sinf rahbari va navbatchi ololmaydi', async () => {
    for (const role of ['HOMEROOM', 'DUTY'] as const) {
      loginAs(role);
      await expect(careService.surveySummaries()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    }
  });
});

describe('simulateSurveyResponses', () => {
  beforeEach(freshDb);

  function run(tables: Tables, minute: number): number {
    return simulateSurveyResponses(tables, TODAY, minute);
  }
  const ofSurvey = (t: Tables, id: string): CareResponse[] => t.careResponses.filter((r) => r.surveyId === id);

  it('deterministik va idempotent; kichikroq daqiqa hech narsa qo\'shmaydi', async () => {
    const id = await activateFreshSurvey(TODAY);
    const a = structuredClone(getTables());
    const b = structuredClone(getTables());
    const first = run(a, 12 * 60);
    expect(first).toBeGreaterThan(0);
    expect(run(a, 12 * 60)).toBe(0);
    expect(run(a, 11 * 60)).toBe(0);
    expect(run(b, 12 * 60)).toBe(first);
    expect(ofSurvey(b, id)).toEqual(ofSurvey(a, id));
    expect(ofSurvey(a, id).every((r) => r.id === `rsp-${id}-${r.studentId}`)).toBe(true);
  });

  it('6 soatlik oyna: faollashtirishdan oldin 0, oyna oxirida ~78%', async () => {
    const id = await activateFreshSurvey(TODAY);
    const t = structuredClone(getTables());
    const start = Date.parse(t.careSurveys.find((s) => s.id === id)?.activatedAt ?? '');
    const startMinute = new Date(start).getHours() * 60 + new Date(start).getMinutes();
    expect(run(t, startMinute - 1)).toBe(0);
    run(t, startMinute + 6 * 60 + 1);
    const responses = ofSurvey(t, id);
    const survey = t.careSurveys.find((s) => s.id === id);
    const rate = responses.length / (survey?.invited ?? 1);
    expect(rate).toBeGreaterThan(SIM_PARTICIPATION - 0.08);
    expect(rate).toBeLessThan(SIM_PARTICIPATION + 0.08);
    expect(new Set(responses.map((r) => r.studentId)).size).toBe(responses.length);
    for (const r of responses) {
      expect(Date.parse(r.submittedAt)).toBeGreaterThanOrEqual(start);
      expect(Date.parse(r.submittedAt)).toBeLessThan(start + 6 * 3_600_000);
      expect(Object.values(r.answers).every((v) => Number.isInteger(v) && v >= 1 && v <= 5)).toBe(true);
    }
  });

  it('tranzaksiyada: javoblar yig\'ilgach so\'rovnoma tayyor bo\'ladi', async () => {
    const id = await activateFreshSurvey(TODAY);
    const created = transact((t) => run(t, 23 * 60));
    expect(created).toBeGreaterThan(CARE_MIN_GROUP);
    loginAs('DIRECTOR');
    expect((await careService.surveyOptions()).find((o) => o.id === id)?.ready).toBe(true);
    expect((await careService.aggregate({ breakdown: 'SCHOOL' })).surveyId).toBe(id);
  });

  it('faol so\'rovnoma bo\'lmasa — 0', () => {
    const t = structuredClone(getTables());
    t.careSurveys = t.careSurveys.map((s) => ({ ...s, status: 'CLOSED' as const }));
    expect(run(t, 23 * 60)).toBe(0);
  });
});

describe('M1: ota-onalar ulanishi — yagona hisob', () => {
  beforeEach(freshDb);

  it('dashboard, /parents statistikasi va hisobot bir xil sonlarni beradi', async () => {
    for (const role of ['DIRECTOR', 'HOMEROOM'] as const) {
      loginAs(role);
      const summary = await parentsService.linkSummary();
      const stats = await guardiansService.stats();
      expect((await dashboardService.overview()).parents).toEqual(summary);
      expect(summary.guardians.total).toBe(stats.total);
      expect(summary.guardians.linked).toBe(stats.LINKED);
      expect(summary.guardians.invited).toBe(stats.INVITED);
      expect(summary.students.rate).toBe(percent(summary.students.linked, summary.students.total));
      expect(summary.guardians.rate).toBe(percent(summary.guardians.linked, summary.guardians.total));
    }
    loginAs('DIRECTOR');
    const report = await reportsService.monthly('2026-10');
    const summary = await parentsService.linkSummary();
    expect(report.parents?.linkedStudents).toBe(summary.students.linked);
    expect(report.parents?.totalStudents).toBe(summary.students.total);
  });

  it('ruxsat: psixolog (students.view) — ha, navbatchi — yo\'q', async () => {
    loginAs('PSYCHOLOGIST');
    await expect(parentsService.linkSummary()).resolves.toBeTruthy();
    loginAs('DUTY');
    await expect(parentsService.linkSummary()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('M3: davomat KPI — qiymat va chiziq bir xil asosda', () => {
  beforeEach(freshDb);

  it('hech kim aniqlanmagan bo\'lsa rate = null ("—")', async () => {
    loginAs('DIRECTOR');
    const att = (await dashboardService.overview()).attendance;
    expect(att?.decided).toBe(0);
    expect(att?.rate).toBeNull();
    expect(att?.counts.pending).toBe(att?.counts.total);
  });

  it('kelganlar / aniqlanganlar', async () => {
    transact((t) => simulate(t, TODAY, 10 * 60));
    loginAs('DIRECTOR');
    const att = (await dashboardService.overview()).attendance;
    expect(att?.decided).toBeGreaterThan(0);
    expect(att?.decided).toBe((att?.counts.total ?? 0) - (att?.counts.pending ?? 0));
    expect(att?.rate).toBe(percent(att?.arrived ?? 0, att?.decided ?? 0));
  });
});

describe('Bosh sahifa ogohlantirish turlari va yangi bloklar', () => {
  beforeEach(freshDb);

  type DemoRole = Exclude<RoleKey, 'TEACHER'>;
  const ALLOWED: Record<DemoRole, DashboardAlertKind[]> = {
    DIRECTOR: ['EMERGENCY', 'SAFETY_SIGNAL', 'ABSENT', 'VERIFICATION', 'NO_PERMISSION'],
    ADMIN: ['EMERGENCY', 'EARLY_EXIT', 'ABSENT', 'VERIFICATION', 'NO_PERMISSION'],
    HOMEROOM: ['EMERGENCY', 'EARLY_EXIT', 'ABSENT', 'NO_PERMISSION'],
    PSYCHOLOGIST: ['CARE_URGENT', 'CARE_NEW'],
    DUTY: ['SAFETY_SIGNAL', 'ABSENT'],
  };

  it('har rol faqat o\'ziga tegishli turlarni oladi, sonlar musbat va takrorsiz', async () => {
    transact((t) => simulate(t, TODAY, 10 * 60));
    loginAs('PSYCHOLOGIST');
    await careService.activateProtocol(URGENT_NEW);
    for (const role of Object.keys(ALLOWED) as DemoRole[]) {
      const allowed = ALLOWED[role];
      loginAs(role);
      const alerts = (await dashboardService.overview()).alerts;
      expect(alerts.every((a) => allowed.includes(a.kind)), role).toBe(true);
      expect(alerts.every((a) => a.count > 0), role).toBe(true);
      expect(new Set(alerts.map((a) => a.kind)).size, role).toBe(alerts.length);
    }
    loginAs('PSYCHOLOGIST');
    expect(await alertKinds()).toEqual(expect.arrayContaining(['CARE_URGENT', 'CARE_NEW']));
  });

  it('ochiq so\'rovlar va rivojlanish bloklari ruxsatga bog\'liq', async () => {
    loginAs('PSYCHOLOGIST');
    const psych = await dashboardService.overview();
    expect(psych.openRequests).toBeNull();
    loginAs('DUTY');
    const duty = await dashboardService.overview();
    expect(duty.development).toBeNull();
    expect(duty.parents).toBeNull();
  });
});
