import { errorLabel } from './error-label';

describe('errorLabel', () => {
  it('keeps only the error type, never the message (it may contain names or text)', () => {
    const err = new Error('Invalid prisma.upsert() invocation: studentName: "Aliyev Vali"');

    expect(errorLabel(err)).toBe('Error');
  });

  it('adds a Prisma-style code when present', () => {
    const err = Object.assign(new Error('Unique constraint failed on "Aliyev"'), { name: 'PrismaClientKnownRequestError', code: 'P2002' });

    expect(errorLabel(err)).toBe('PrismaClientKnownRequestError P2002');
  });

  it('handles non-Error throwables', () => {
    expect(errorLabel('boom')).toBe("noma'lum xato");
    expect(errorLabel(undefined)).toBe("noma'lum xato");
  });
});
