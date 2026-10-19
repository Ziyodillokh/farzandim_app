import { ArgumentsHost, BadRequestException } from '@nestjs/common';
import { GlobalExceptionFilter } from './global-exception.filter';

function run(exception: unknown) {
  const reply = { status: jest.fn().mockReturnThis(), send: jest.fn() };
  const host = {
    switchToHttp: () => ({ getResponse: () => reply }),
  } as unknown as ArgumentsHost;
  new GlobalExceptionFilter().catch(exception, host);
  return { status: reply.status.mock.calls[0][0], body: reply.send.mock.calls[0][0] };
}

describe('GlobalExceptionFilter', () => {
  it('HttpException holati va javobi saqlanadi', () => {
    const { status, body } = run(new BadRequestException('yomon'));
    expect(status).toBe(400);
    expect(body).toMatchObject({ statusCode: 400, message: 'yomon' });
  });

  it('Prisma P2025 → 404, P2002 → 409, P2003 → 400', () => {
    expect(run({ code: 'P2025' }).status).toBe(404);
    expect(run({ code: 'P2002' })).toEqual({
      status: 409,
      body: { statusCode: 409, message: 'Resource already exists' },
    });
    expect(run({ code: 'P2003' }).status).toBe(400);
  });

  it('noma\'lum xato → 500 (tafsilot oshkor qilinmaydi)', () => {
    const { status, body } = run(new Error('db parol: secret'));
    expect(status).toBe(500);
    expect(body).toEqual({ statusCode: 500, message: 'Internal server error' });
  });
});
