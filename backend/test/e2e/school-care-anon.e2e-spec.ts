// Bola ovozi — HAQIQIY ANONIM so'rovnoma: ishtirok va javob alohida jadvallarda, hech bir
// ustun / id / vaqt belgisi javobni o'quvchiga bog'lamaydi; ikki bolaning javobini hech bir
// API orqali ajratib bo'lmaydi; eski (bog'langan) va yangi javoblar bir xil hisoblanadi.

import { SchoolCryptoService } from '../../src/school/common/school-crypto.service';
import { resetDb } from './db';
import { createTestApp, TestApp } from './test-app';
import { activateSurvey, answersOf, AssessWorld, buildWorld, careChild, careStaff, enroll, Kid, schoolApi } from './school-care-fixtures';

describe('Bola ovozi — anonim so\'rovnoma', () => {
  let t: TestApp;
  let w: AssessWorld;
  let staff: ReturnType<typeof careStaff>;
  let child: ReturnType<typeof careChild>;
  let school: ReturnType<typeof schoolApi>;

  beforeAll(async () => {
    t = await createTestApp();
    staff = careStaff(t);
    child = careChild(t);
    school = schoolApi(t);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    w = await buildWorld(t);
  });

  afterAll(() => t.close());

  const columns = async (table: string) =>
    (await t.prisma.$queryRaw<{ column_name: string }[]>`SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = ${table}`).map((c) => c.column_name);

  it('bazadagi anonim jadvalda o\'quvchi / bola / vaqt ustuni umuman yo\'q', async () => {
    const names = await columns('school_care_anon_responses');
    expect(names.sort()).toEqual(['age_group', 'answers_enc', 'class_id', 'grade', 'id', 'school_id', 'survey_id']);
    expect(names.join(' ')).not.toMatch(/student|child|user|created|updated|submitted|_at|time|date/);
    // Ishtirok jadvalida esa javob ustuni yo'q.
    expect((await columns('school_care_participation')).sort()).toEqual(['created_at', 'id', 'student_id', 'survey_id']);
  });

  it('ikki bola turlicha javob beradi — qatorlar, hech bir API javobi ularni bog\'lamaydi yoki ajratmaydi', async () => {
    const [a, b] = w.kids7a as [Kid, Kid];
    const survey = await activateSurvey(t, w.psych);
    expect((await child(a, 'POST', `/survey/${survey.id}/responses`, { answers: answersOf(survey.questionIds, 1) })).statusCode).toBe(201);
    expect((await child(b, 'POST', `/survey/${survey.id}/responses`, { answers: answersOf(survey.questionIds, 5) })).statusCode).toBe(201);

    // Bazada: ikki ishtirok (o'quvchi id bilan, javobsiz) va ikki anonim qator (id'siz).
    const participation = await t.prisma.schoolCareParticipation.findMany();
    expect(participation.map((p) => p.studentId).sort()).toEqual([a.studentId, b.studentId].sort());
    const anon = await t.prisma.schoolCareAnonResponse.findMany();
    expect(anon).toHaveLength(2);
    const secrets = [a.studentId, b.studentId, a.childId, b.childId, a.userId, b.userId, ...participation.map((p) => p.id)];
    for (const row of anon) {
      expect(Object.keys(row).sort()).toEqual(['ageGroup', 'answersEnc', 'classId', 'grade', 'id', 'schoolId', 'surveyId']);
      expect(secrets).not.toContain(row.id);
      for (const value of Object.values(row)) expect(secrets).not.toContain(value);
      expect(JSON.stringify(row)).not.toMatch(/\d{4}-\d{2}-\d{2}T\d{2}:/);
    }
    expect(await t.prisma.schoolCareResponse.count()).toBe(0);

    // Javoblar shifrlangan; ochilganda faqat 1 lar va 5 lar to'plami (kim ekani yo'q).
    const crypto = t.app.get(SchoolCryptoService);
    const decoded = anon.map((r) => Object.values(crypto.decryptJson<Record<string, number>>(r.answersEnc)).join(','));
    expect(decoded.sort()).toEqual(['1,1,1,1', '5,5,5,5']);

    // Barcha xodim o'qish API'lari: na id, na ism, na alohida javob.
    const dump: string[] = [];
    for (const [who, url] of [
      [w.psych, '/aggregate?breakdown=SCHOOL'],
      [w.psych, '/aggregate?breakdown=CLASS'],
      [w.psych, '/aggregate?breakdown=GRADE'],
      [w.psych, '/aggregate?breakdown=AGE_GROUP'],
      [w.psych, '/surveys'],
      [w.psych, '/surveys/options'],
      [w.psych, '/surveys/summaries'],
      [w.psych, '/requests'],
      [w.psych, '/settings'],
      [w.director, '/aggregate?breakdown=SCHOOL'],
      [w.director, '/surveys/options'],
      [w.director, '/surveys/summaries'],
      [w.director, '/settings'],
    ] as const) {
      const res = await staff(who, 'GET', url);
      expect(res.statusCode).toBe(200);
      dump.push(res.body);
    }
    dump.push((await school(w.director, 'GET', '/reports/monthly?month=2026-11')).body);
    dump.push((await school(w.psych, 'GET', '/dashboard/overview')).body);
    const all = dump.join('\n');
    for (const secret of secrets) expect(all).not.toContain(secret);
    for (const kid of [a, b]) expect(all).not.toContain(kid.studentCode);
    expect(all).not.toContain(anon[0]!.id);
    expect(all).not.toContain(anon[1]!.id);
    expect(all).not.toContain('Alfa0');
    expect(all).not.toContain('Alfa1');

    // K=5 dan kichik: na umumiy ko'rsatkich, na guruh — ikki bolaning farqini ko'rib bo'lmaydi.
    const aggregate = (await staff(w.psych, 'GET', `/aggregate?surveyId=${survey.id}&breakdown=CLASS`)).json();
    expect(aggregate).toMatchObject({ respondents: 2, overall: {} });
    expect(aggregate.groups.every((g: { hidden: boolean; topicScores: unknown }) => g.hidden && g.topicScores === null)).toBe(true);
  });

  it('eski (bog\'langan) va yangi (anonim) javoblar bir xil hisoblanadi', async () => {
    const survey = await activateSurvey(t, w.psych);
    const kids = [...w.kids7a, ...(await enroll(t, w.schoolId, w.classes.c7a, 3, 'uz', 'Gamma'))];
    const crypto = t.app.get(SchoolCryptoService);
    // 3 ta eski qator (migratsiyadan oldingi) + 2 ta yangi anonim = 5 respondent.
    for (const kid of kids.slice(0, 3)) {
      await t.prisma.schoolCareResponse.create({
        data: { schoolId: w.schoolId, surveyId: survey.id, studentId: kid.studentId, classId: w.classes.c7a, grade: 7, answersEnc: crypto.encryptJson(answersOf(survey.questionIds, 3)) },
      });
    }
    for (const kid of kids.slice(3, 5)) {
      expect((await child(kid, 'POST', `/survey/${survey.id}/responses`, { answers: answersOf(survey.questionIds, 5) })).statusCode).toBe(201);
    }

    // `answered`: eski qator ham, ishtirok ham hisobga olinadi; eski javob bergan bola qayta yubora olmaydi.
    expect((await child(kids[0]!, 'GET', '/survey')).json()).toMatchObject({ answered: true, survey: null });
    expect((await child(kids[3]!, 'GET', '/survey')).json()).toMatchObject({ answered: true, survey: null });
    expect((await child(kids[0]!, 'POST', `/survey/${survey.id}/responses`, { answers: answersOf(survey.questionIds, 2) })).json().code).toBe('ALREADY_ANSWERED');
    expect(await t.prisma.schoolCareAnonResponse.count()).toBe(2);

    // Faol so'rovnomada psixolog ham ko'rsatkichni ko'rmaydi (faqat ishtirok soni).
    const live = (await staff(w.psych, 'GET', `/aggregate?surveyId=${survey.id}&breakdown=SCHOOL`)).json();
    expect(live).toMatchObject({ respondents: 5, overall: {}, groups: [] });
    const list = (await staff(w.psych, 'GET', '/surveys')).json();
    expect(list[0]).toMatchObject({ id: survey.id, respondents: 5 });
    await staff(w.psych, 'POST', `/surveys/${survey.id}/close`);
    const closed = (await staff(w.director, 'GET', '/aggregate?breakdown=SCHOOL')).json();
    expect(closed).toMatchObject({ surveyId: survey.id, respondents: 5 });
    // Yopilgach eski va anonim qatorlar birga hisoblanadi: ko'rsatkichlar paydo bo'ladi (psixolog ham ko'radi).
    expect(Object.keys(closed.overall).length).toBeGreaterThan(0);
    expect(Object.keys((await staff(w.psych, 'GET', `/aggregate?surveyId=${survey.id}&breakdown=SCHOOL`)).json().overall).length).toBeGreaterThan(0);
    expect((await staff(w.director, 'GET', '/surveys/summaries')).json()[0].participation).toMatchObject({ respondents: 5 });
  });

  it('GET survey: faollashtirilgan vaqt, savollar soni va taxminiy vaqt; o\'tkazilgan savol 0 bo\'lib saqlanmaydi', async () => {
    const survey = await activateSurvey(t, w.psych, 8);
    const view = (await child(w.kids7a[0]!, 'GET', '/survey')).json();
    expect(view).toMatchObject({ enrolled: true, answered: false, survey: { id: survey.id, questionCount: 8, estimatedMinutes: 2 } });
    expect(new Date(view.survey.activatedAt).toISOString()).toBe(view.survey.activatedAt);
    expect(Object.keys(view.survey).sort()).toEqual(['activatedAt', 'estimatedMinutes', 'id', 'questionCount', 'questions', 'title']);
    expect(Object.keys(view.survey.questions[0]).sort()).toEqual(['id', 'text']);

    const only = survey.questionIds.slice(0, 3);
    const answers = Object.fromEntries(only.map((q, i) => [q, i + 1]));
    const res = await child(w.kids7a[0]!, 'POST', `/survey/${survey.id}/responses`, { answers });
    expect(res.json()).toEqual({ ok: true });
    const stored = await t.prisma.schoolCareAnonResponse.findFirstOrThrow();
    expect(t.app.get(SchoolCryptoService).decryptJson(stored.answersEnc)).toEqual(answers);
    expect(stored.answersEnc).not.toContain(only[0]);
  });

  it('tekshiruvlar: bo\'sh / noma\'lum savol / 1..5 dan tashqari — 400; boshqa maktab bolasi — 404', async () => {
    const survey = await activateSurvey(t, w.psych);
    const kid = w.kids7a[0]!;
    const post = (body: unknown, who: { token: string } = kid) => child(who, 'POST', `/survey/${survey.id}/responses`, body);
    expect((await post({ answers: {} })).json()).toMatchObject({ code: 'VALIDATION', message: 'answers: errors.form.selectAtLeastOne' });
    expect((await post({ answers: { 'not-a-question': 3 } })).json()).toMatchObject({ code: 'VALIDATION' });
    expect((await post({ answers: { [survey.questionIds[0]!]: 0 } })).statusCode).toBe(400);
    expect((await post({ answers: { [survey.questionIds[0]!]: 6 } })).statusCode).toBe(400);
    expect((await post({ answers: { [survey.questionIds[0]!]: 'x' } })).statusCode).toBe(400);
    expect(await t.prisma.schoolCareParticipation.count()).toBe(0);
    expect(await t.prisma.schoolCareAnonResponse.count()).toBe(0);

    const other = await buildWorld(t, 'other-school');
    expect((await post({ answers: { [survey.questionIds[0]!]: 3 } }, other.kids7a[0]!)).json().code).toBe('SURVEY_NOT_FOUND');
    expect(await t.prisma.schoolCareAnonResponse.count()).toBe(0);
  });

  it('parallel ikki marta yuborish: bitta ishtirok, bitta anonim qator, biri 409', async () => {
    const survey = await activateSurvey(t, w.psych);
    const kid = w.kids7a[0]!;
    const body = { answers: answersOf(survey.questionIds, 4) };

    const results = await Promise.all(Array.from({ length: 4 }, () => child(kid, 'POST', `/survey/${survey.id}/responses`, body)));

    expect(results.map((r) => r.statusCode).sort()).toEqual([201, 409, 409, 409]);
    expect(await t.prisma.schoolCareParticipation.count()).toBe(1);
    expect(await t.prisma.schoolCareAnonResponse.count()).toBe(1);
  });

  it('ishtirok yozilmasa anonim qator ham qolmaydi (bitta tranzaksiya)', async () => {
    const survey = await activateSurvey(t, w.psych);
    const kid = w.kids7a[0]!;
    await t.prisma.schoolCareParticipation.create({ data: { surveyId: survey.id, studentId: kid.studentId } });

    const res = await child(kid, 'POST', `/survey/${survey.id}/responses`, { answers: answersOf(survey.questionIds, 4) });

    expect(res.statusCode).toBe(409);
    expect(await t.prisma.schoolCareAnonResponse.count()).toBe(0);
  });

  it('anonim qator yozilmasa ishtirok ham qolmaydi: bola qayta urinib ko\'ra oladi (atomiklik)', async () => {
    const survey = await activateSurvey(t, w.psych);
    const kid = w.kids7a[0]!;
    const body = { answers: answersOf(survey.questionIds, 4) };
    await t.prisma.$executeRawUnsafe(`CREATE OR REPLACE FUNCTION e2e_fail_anon() RETURNS trigger AS $$ BEGIN RAISE EXCEPTION 'e2e: anon insert failed'; END; $$ LANGUAGE plpgsql`);
    await t.prisma.$executeRawUnsafe('CREATE TRIGGER e2e_fail_anon BEFORE INSERT ON school_care_anon_responses FOR EACH ROW EXECUTE FUNCTION e2e_fail_anon()');
    try {
      expect((await child(kid, 'POST', `/survey/${survey.id}/responses`, body)).statusCode).toBe(500);
      expect(await t.prisma.schoolCareParticipation.count()).toBe(0);
    } finally {
      await t.prisma.$executeRawUnsafe('DROP TRIGGER e2e_fail_anon ON school_care_anon_responses');
      await t.prisma.$executeRawUnsafe('DROP FUNCTION e2e_fail_anon()');
    }

    expect((await child(kid, 'POST', `/survey/${survey.id}/responses`, body)).statusCode).toBe(201);
    expect(await t.prisma.schoolCareParticipation.count()).toBe(1);
    expect(await t.prisma.schoolCareAnonResponse.count()).toBe(1);
  });
});
