import { ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { requireEnrolledStudent } from '../common/child-student';
import { ANON_ROW_FIELDS, buildAnonRow } from './care-anon';
import { CareChildService } from './care-child.service';

jest.mock('../common/child-student', () => ({
  findEnrolledStudent: jest.fn(),
  requireEnrolledStudent: jest.fn(),
}));

/** Anonim qatorda bo'lishi MUMKIN BO'LMAGAN ustun nomlari: o'quvchi, bola, foydalanuvchi, vaqt belgisi. */
const FORBIDDEN_COLUMN = /student|child|user|guardian|parent|created|updated|submitted|taken|completed|timestamp|time|date|(^|_)at$|At$/i;

describe('SchoolCareAnonResponse (database shape)', () => {
  const model = Prisma.dmmf.datamodel.models.find((m) => m.name === 'SchoolCareAnonResponse');

  it('exists in the schema', () => {
    expect(model).toBeDefined();
  });

  it('has NO student / child / user / timestamp column', () => {
    const names = model!.fields.map((f) => f.name);
    expect(names.filter((n) => FORBIDDEN_COLUMN.test(n))).toEqual([]);
  });

  it('has NO DateTime column of any name', () => {
    expect(model!.fields.filter((f) => f.type === 'DateTime').map((f) => f.name)).toEqual([]);
  });

  it('only relates to school and survey (never to a student)', () => {
    const relations = model!.fields.filter((f) => f.kind === 'object').map((f) => f.type).sort();
    expect(relations).toEqual(['School', 'SchoolCareSurvey']);
  });

  it('has exactly the allow-listed columns plus the random primary key', () => {
    expect(model!.fields.filter((f) => f.kind === 'scalar').map((f) => f.name).sort()).toEqual(['id', ...ANON_ROW_FIELDS].sort());
    const id = model!.fields.find((f) => f.name === 'id')!;
    expect(id.hasDefaultValue && JSON.stringify(id.default)).toContain('uuid');
  });

  it('keeps who-answered in the participation table, which has no answer column', () => {
    const participation = Prisma.dmmf.datamodel.models.find((m) => m.name === 'SchoolCareParticipation')!;
    expect(participation.fields.map((f) => f.name).sort()).toEqual(['createdAt', 'id', 'studentId', 'survey', 'surveyId']);
    expect(participation.fields.some((f) => /answer|response/i.test(f.name))).toBe(false);
  });
});

describe('buildAnonRow', () => {
  const row = buildAnonRow({
    surveyId: 'survey-1',
    schoolId: 'school-1',
    classId: 'class-7a',
    grade: 7,
    answers: { q1: 4, q2: 2 },
    encrypt: (answers) => `enc(${JSON.stringify(answers)})`,
  });

  it('contains only the allow-listed fields', () => {
    expect(Object.keys(row).sort()).toEqual([...ANON_ROW_FIELDS].sort());
  });

  it('has no studentId, childId or timestamp-like key', () => {
    expect(Object.keys(row).filter((k) => FORBIDDEN_COLUMN.test(k))).toEqual([]);
    expect(Object.values(row).some((v) => v instanceof Date)).toBe(false);
  });

  it('derives the age group from the grade and encrypts the answers', () => {
    expect(row.ageGroup).toBe('G5_8');
    expect(row.answersEnc).toBe('enc({"q1":4,"q2":2})');
    expect(JSON.stringify({ ...row, answersEnc: '' })).not.toContain('q1');
  });
});

describe('CareChildService.submitSurvey (anonymity of the write path)', () => {
  const STUDENT = { childId: 'child-secret', studentId: 'student-secret', schoolId: 'school-1', classId: 'class-7a', className: '7-A', grade: 7, lang: 'uz' as const };

  function setup(options: { participationConflict?: boolean; surveyStatus?: string } = {}) {
    const calls: string[] = [];
    const tx = {
      $queryRaw: jest.fn().mockResolvedValue([{ status: options.surveyStatus ?? 'ACTIVE' }]),
      schoolCareResponse: { count: jest.fn().mockResolvedValue(0) },
      schoolCareParticipation: {
        create: jest.fn().mockImplementation(async () => {
          calls.push('participation');
          if (options.participationConflict) throw new Prisma.PrismaClientKnownRequestError('dup', { code: 'P2002', clientVersion: 'test' });
          return {};
        }),
      },
      schoolCareAnonResponse: {
        create: jest.fn().mockImplementation(async () => {
          calls.push('anon');
          return {};
        }),
      },
    };
    const inTransaction = jest.fn();
    const prisma = {
      schoolCareSurvey: { findFirst: jest.fn().mockResolvedValue({ id: 'survey-1', questionIds: ['q1', 'q2'] }) },
      schoolCareQuestion: { findMany: jest.fn().mockResolvedValue([{ id: 'q1' }, { id: 'q2' }]) },
      $transaction: jest.fn().mockImplementation(async (fn: (t: typeof tx) => Promise<unknown>) => {
        inTransaction();
        return fn(tx);
      }),
    };
    const crypto = { encryptJson: jest.fn((v: unknown) => `v1.enc.${Buffer.from(JSON.stringify(v)).toString('base64url')}`) };
    (requireEnrolledStudent as jest.Mock).mockResolvedValue(STUDENT);
    return { service: new CareChildService(prisma as never, crypto as never), prisma, tx, calls, inTransaction };
  }

  it('writes participation and the anonymous row in ONE transaction', async () => {
    const { service, prisma, calls, inTransaction } = setup();

    await expect(service.submitSurvey('child-user', 'survey-1', { answers: { q1: 5 } })).resolves.toEqual({ ok: true });

    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(inTransaction).toHaveBeenCalledTimes(1);
    expect(calls).toEqual(['participation', 'anon']);
  });

  it('stores no student / child id and no timestamp in the anonymous row', async () => {
    const { service, tx } = setup();

    await service.submitSurvey('child-user', 'survey-1', { answers: { q1: 5, q2: 3 } });

    const data = tx.schoolCareAnonResponse.create.mock.calls[0]![0].data as Record<string, unknown>;
    expect(Object.keys(data).sort()).toEqual([...ANON_ROW_FIELDS].sort());
    const serialized = JSON.stringify(data);
    expect(serialized).not.toContain('student-secret');
    expect(serialized).not.toContain('child-secret');
    expect(serialized).not.toContain('child-user');
    expect(tx.schoolCareParticipation.create.mock.calls[0]![0].data).toEqual({ surveyId: 'survey-1', studentId: 'student-secret' });
  });

  it('omits skipped questions instead of storing them as 0', async () => {
    const { service, tx } = setup();

    await service.submitSurvey('child-user', 'survey-1', { answers: { q2: 4 } });

    const { answersEnc } = tx.schoolCareAnonResponse.create.mock.calls[0]![0].data as { answersEnc: string };
    expect(JSON.parse(Buffer.from(answersEnc.split('.')[2]!, 'base64url').toString())).toEqual({ q2: 4 });
  });

  it('rejects an unknown question id with 400 and writes nothing', async () => {
    const { service, prisma } = setup();

    await expect(service.submitSurvey('child-user', 'survey-1', { answers: { q1: 5, nope: 3 } })).rejects.toMatchObject({
      response: { code: 'VALIDATION', message: 'answers: errors.form.invalid' },
    });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects an empty answer set with the select-at-least-one key', async () => {
    const { service } = setup();

    await expect(service.submitSurvey('child-user', 'survey-1', { answers: {} })).rejects.toMatchObject({
      response: { code: 'VALIDATION', message: 'answers: errors.form.selectAtLeastOne' },
    });
  });

  it('answers 409 ALREADY_ANSWERED and writes no anonymous row when participation already exists', async () => {
    const { service, tx } = setup({ participationConflict: true });

    await expect(service.submitSurvey('child-user', 'survey-1', { answers: { q1: 5 } })).rejects.toBeInstanceOf(ConflictException);
    expect(tx.schoolCareAnonResponse.create).not.toHaveBeenCalled();
  });

  it('rejects with 404 and writes nothing when the survey was closed meanwhile (row lock re-check)', async () => {
    const { service, tx } = setup({ surveyStatus: 'CLOSED' });

    await expect(service.submitSurvey('child-user', 'survey-1', { answers: { q1: 5 } })).rejects.toMatchObject({ response: { code: 'SURVEY_NOT_FOUND' } });
    expect(tx.schoolCareParticipation.create).not.toHaveBeenCalled();
    expect(tx.schoolCareAnonResponse.create).not.toHaveBeenCalled();
  });

  it('answers 409 when a legacy (student-linked) response already exists', async () => {
    const { service, tx } = setup();
    tx.schoolCareResponse.count.mockResolvedValue(1);

    await expect(service.submitSurvey('child-user', 'survey-1', { answers: { q1: 5 } })).rejects.toMatchObject({ response: { code: 'ALREADY_ANSWERED' } });
    expect(tx.schoolCareParticipation.create).not.toHaveBeenCalled();
    expect(tx.schoolCareAnonResponse.create).not.toHaveBeenCalled();
  });
});
