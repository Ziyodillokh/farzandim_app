import { linkCorrectionSchema, redeemSchema, studentCodeSchema } from './students.schemas';

const UUID = '3f9c1c1e-6a1b-4c1e-9d5e-0a3f4b6c7d8e';

describe('redeemSchema (parent app)', () => {
  it.each([
    ['abcd-2345', 'ABCD2345'],
    [' ab cd 23 45 ', 'ABCD2345'],
    ['048213', '048213'],
    ['048 213', '048213'],
    ['048-213', '048213'],
  ])('accepts %j as %j', (input, expected) => {
    expect(redeemSchema.parse({ code: input })).toEqual({ code: expected });
  });

  it.each(['', 'AB', '12345', '1234567', '123456789', 'ABCDEFG', 'ABCD234!', 'ABCDE2345'])('rejects %j', (input) => {
    const result = redeemSchema.safeParse({ code: input });
    expect(result.success).toBe(false);
  });

  it('rejects non-strings and a missing code', () => {
    expect(redeemSchema.safeParse({ code: 123456 }).success).toBe(false);
    expect(redeemSchema.safeParse({}).success).toBe(false);
  });
});

describe('studentCodeSchema (child app)', () => {
  it('accepts exactly six digits ignoring spaces and dashes', () => {
    expect(studentCodeSchema.parse({ code: '000123' })).toEqual({ code: '000123' });
    expect(studentCodeSchema.parse({ code: ' 000-123 ' })).toEqual({ code: '000123' });
  });

  it.each(['', '12345', '1234567', 'ABCDEFGH', 'AB12CD', '12.456'])('rejects %j (8-character guardian codes are not student codes)', (input) => {
    expect(studentCodeSchema.safeParse({ code: input }).success).toBe(false);
  });

  it('reports the error with the i18n key', () => {
    const result = studentCodeSchema.safeParse({ code: 'abc' });
    expect(result.success ? '' : result.error.issues[0]?.message).toBe('errors.school.studentCodeFormat');
  });
});

describe('linkCorrectionSchema', () => {
  const valid = { reason: 'WRONG_SCHOOL_OR_CLASS', note: ' Sinfim 7-B ', clientRequestId: UUID };

  it('trims the note and defaults it to empty', () => {
    expect(linkCorrectionSchema.parse(valid)).toEqual({ ...valid, note: 'Sinfim 7-B' });
    expect(linkCorrectionSchema.parse({ reason: valid.reason, clientRequestId: UUID }).note).toBe('');
  });

  it('allows a 300 character note but not 301', () => {
    expect(linkCorrectionSchema.safeParse({ ...valid, note: 'x'.repeat(300) }).success).toBe(true);
    expect(linkCorrectionSchema.safeParse({ ...valid, note: 'x'.repeat(301) }).success).toBe(false);
  });

  it.each([
    ['unknown reason', { reason: 'OTHER' }],
    ['missing reason', { reason: undefined }],
    ['missing clientRequestId', { clientRequestId: undefined }],
    ['non-uuid clientRequestId', { clientRequestId: '12345' }],
    ['numeric note', { note: 5 }],
  ])('rejects %s', (_name, patch) => {
    expect(linkCorrectionSchema.safeParse({ ...valid, ...patch }).success).toBe(false);
  });
});
