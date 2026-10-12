import { beforeEach, describe, expect, it } from 'vitest';

import type { CareAggregate } from '@/data/contracts';
import { CARE_BREAKDOWNS } from '@/data/schemas/care';
import { CARE_MIN_GROUP } from '@/lib/k-anon';
import { getTables, transact } from '../db';
import { careService } from '../services/care';
import { freshDb, loginAs } from './helpers';

/** Obyektdagi barcha kalitlar (chuqur). */
function deepKeys(value: unknown, out: Set<string> = new Set()): Set<string> {
  if (Array.isArray(value)) {
    for (const item of value) deepKeys(item, out);
  } else if (value && typeof value === 'object') {
    for (const [key, child] of Object.entries(value)) {
      out.add(key);
      deepKeys(child, out);
    }
  }
  return out;
}

function activeSurveyId(): string {
  const survey = getTables().careSurveys.find((s) => s.status === 'ACTIVE');
  if (!survey) throw new Error('no active survey');
  return survey.id;
}

/** Sinf javoblarini `keep` tagacha qisqartirish (k-anonimlikni sinash uchun). */
function shrinkClass(surveyId: string, classId: string, keep: number): void {
  transact((t) => {
    let left = keep;
    t.careResponses = t.careResponses.filter((r) => {
      if (r.surveyId !== surveyId || r.classId !== classId) return true;
      left -= 1;
      return left >= 0;
    });
  });
}

describe('Bola ovozi — ruxsatlar', () => {
  beforeEach(freshDb);

  it('direktor murojaatlar ro\'yxatini ololmaydi (FORBIDDEN)', async () => {
    loginAs('DIRECTOR');
    await expect(careService.listRequests()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(careService.getRequest('care-1')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('admin ham shaxsiy murojaat va so\'rovnomalarga kira olmaydi', async () => {
    loginAs('ADMIN');
    await expect(careService.listRequests()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(careService.listSurveys()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(careService.activateProtocol('care-1')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('sinf rahbari umumlashgan natijani ham ko\'rmaydi', async () => {
    loginAs('HOMEROOM');
    await expect(careService.aggregate({ breakdown: 'SCHOOL' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('psixolog murojaatlarni ism va sinf bilan ko\'radi', async () => {
    loginAs('PSYCHOLOGIST');
    const list = await careService.listRequests();
    expect(list.items.length).toBeGreaterThan(0);
    expect(list.items[0]?.studentName).not.toBe('—');
    expect(list.items[0]?.urgency).toBe('URGENT');
    const total = Object.values(list.counts).reduce((a, b) => a + b, 0);
    expect(total).toBe(list.items.length);
  });
});

describe('Bola ovozi — umumlashgan natija (k-anonimlik)', () => {
  beforeEach(freshDb);

  it('natijada studentId yoki shaxsiy maydon yo\'q (barcha kesimlar)', async () => {
    loginAs('DIRECTOR');
    const studentIds = new Set(getTables().students.map((s) => s.id));
    for (const breakdown of CARE_BREAKDOWNS) {
      const result: CareAggregate = await careService.aggregate({ breakdown });
      const keys = deepKeys(result);
      for (const forbidden of ['studentId', 'answers', 'message', 'classId', 'notes']) expect(keys.has(forbidden)).toBe(false);
      const json = JSON.stringify(result);
      for (const id of studentIds) expect(json.includes(`"${id}"`)).toBe(false);
    }
  });

  it('5 tadan kam respondentli guruh yashiriladi', async () => {
    loginAs('DIRECTOR');
    const surveyId = activeSurveyId();
    shrinkClass(surveyId, 'cls-8b', 3);
    const result = await careService.aggregate({ surveyId, breakdown: 'CLASS' });
    const small = result.groups.find((g) => g.key === 'cls-8b');
    expect(small).toMatchObject({ hidden: true, topicScores: null, respondents: 0 });
    for (const g of result.groups) if (!g.hidden) expect(g.respondents).toBeGreaterThanOrEqual(CARE_MIN_GROUP);
  });

  it('ikkilamchi yashirish: bitta kichik guruh bo\'lsa, yana biri yashiriladi', async () => {
    loginAs('DIRECTOR');
    const surveyId = activeSurveyId();
    shrinkClass(surveyId, 'cls-8b', 2);
    const result = await careService.aggregate({ surveyId, breakdown: 'CLASS' });
    const hidden = result.groups.filter((g) => g.hidden);
    expect(hidden.length).toBeGreaterThanOrEqual(2);
    expect(hidden.some((g) => g.key === 'cls-8b')).toBe(true);
    // Yashirilganlarni "jami − ochiqlar" orqali topib bo'lmaydi: qoldiq K dan kam emas.
    const visibleSum = result.groups.filter((g) => !g.hidden).reduce((s, g) => s + g.respondents, 0);
    expect(result.respondents - visibleSum).toBeGreaterThanOrEqual(CARE_MIN_GROUP);
  });

  it('teskari savollar aylantiriladi; ko\'rsatkich 0..100', async () => {
    loginAs('DIRECTOR');
    const surveyId = activeSurveyId();
    transact((t) => {
      const reverse = new Set(t.careQuestions.filter((q) => q.reverse).map((q) => q.id));
      t.careResponses = t.careResponses.map((r) =>
        r.surveyId !== surveyId
          ? r
          : { ...r, answers: Object.fromEntries(Object.keys(r.answers).map((id) => [id, reverse.has(id) ? 1 : 5])) },
      );
    });
    const result = await careService.aggregate({ surveyId, breakdown: 'SCHOOL' });
    const scores = Object.values(result.overall);
    expect(scores.length).toBeGreaterThan(0);
    for (const v of scores) expect(v).toBe(100);
  });

  it('murojaatlar soni kichik bo\'lsa "<5" ko\'rinishida', async () => {
    loginAs('ADMIN');
    transact((t) => {
      t.careRequests = t.careRequests.slice(0, 2).map((r) => ({ ...r, createdAt: '2026-10-12T09:00:00' }));
    });
    const result = await careService.aggregate({ breakdown: 'SCHOOL' });
    expect(result.requestsThisWeek).toBe('<5');
  });
});

describe('Bola ovozi — murojaatlar va protokol', () => {
  beforeEach(freshDb);

  it('himoya protokoli audit jurnaliga yoziladi (tafsilotsiz)', async () => {
    loginAs('PSYCHOLOGIST');
    const target = getTables().careRequests.find((r) => r.urgency === 'URGENT' && !r.protocolActivated);
    expect(target).toBeDefined();
    const updated = await careService.activateProtocol(target!.id);
    expect(updated.protocolActivated).toBe(true);
    expect(updated.notes.at(-1)?.text).toMatch(/direktor/);
    const entry = getTables().audit.at(-1);
    expect(entry).toMatchObject({ module: 'CARE', action: 'care.protocol.activate', entityId: target!.id });
    const json = JSON.stringify(entry);
    expect(json.includes(target!.studentId)).toBe(false);
    expect(json.includes(target!.message)).toBe(false);
    await expect(careService.activateProtocol(target!.id)).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('oddiy murojaatga protokol qo\'llanmaydi', async () => {
    loginAs('PSYCHOLOGIST');
    const normal = getTables().careRequests.find((r) => r.urgency === 'NORMAL');
    await expect(careService.activateProtocol(normal!.id)).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('suhbat belgilash holatni SCHEDULED qiladi; eslatma qo\'shiladi', async () => {
    loginAs('PSYCHOLOGIST');
    const request = getTables().careRequests.find((r) => r.status === 'NEW');
    const scheduled = await careService.scheduleMeeting(request!.id, '2026-10-14T12:30');
    expect(scheduled.status).toBe('SCHEDULED');
    expect(scheduled.meetingAt).toBe('2026-10-14T12:30:00');
    const noted = await careService.addRequestNote(request!.id, 'Suhbat rejasi tuzildi');
    expect(noted.notes.at(-1)?.text).toBe('Suhbat rejasi tuzildi');
    await expect(careService.addRequestNote(request!.id, '  ')).rejects.toMatchObject({ code: 'VALIDATION' });
  });
});

describe('Bola ovozi — so\'rovnomalar', () => {
  beforeEach(freshDb);

  it('psixolog qoralama yaratadi va faollashtiradi — oldingi faol yopiladi', async () => {
    loginAs('PSYCHOLOGIST');
    const previous = activeSurveyId();
    const draft = await careService.createSurvey({ title: 'Sinov', weekStart: '2026-10-19', ageGroups: ['G5_8'], questionIds: ['q-1', 'q-6'] });
    expect(draft.status).toBe('DRAFT');
    expect(draft.invited).toBeGreaterThan(0);
    await careService.activateSurvey(draft.id);
    const surveys = getTables().careSurveys;
    expect(surveys.find((s) => s.id === draft.id)?.status).toBe('ACTIVE');
    expect(surveys.find((s) => s.id === previous)?.status).toBe('CLOSED');
  });

  it('yosh guruhiga mos kelmagan savol rad etiladi; ishlatilgan savol o\'chirilmaydi', async () => {
    loginAs('PSYCHOLOGIST');
    await expect(
      careService.createSurvey({ title: 'X', weekStart: '2026-10-19', ageGroups: ['G1_4'], questionIds: ['q-14'] }),
    ).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(careService.deleteQuestion('q-1')).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('direktor so\'rovnoma yarata olmaydi', async () => {
    loginAs('DIRECTOR');
    await expect(
      careService.createSurvey({ title: 'X', weekStart: '2026-10-19', ageGroups: ['G5_8'], questionIds: ['q-1'] }),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});
