import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { encodeLedgerCursor } from './don-ledger';
import { DonLedgerService } from './don-ledger.service';

const ID = '3f2b8c1e-9a4d-4e7b-8c51-0d6f2a9b7e14';

function serviceFailingWith(error: Error): DonLedgerService {
  const prisma = {
    child: { findUnique: jest.fn().mockResolvedValue({ id: 'c1', parentId: 'u1', childUserId: 'u2' }) },
    childProfile: { findUnique: jest.fn().mockResolvedValue({ donBalance: 7 }) },
    xpEvent: { findMany: jest.fn().mockRejectedValue(error) },
  };
  return new DonLedgerService(prisma as never);
}

const cursor = encodeLedgerCursor({ at: new Date('2026-11-05T09:12:00.000Z'), id: ID });

describe('DonLedgerService — kursor xatolari', () => {
  it.each([
    ['PrismaClientValidationError', new Prisma.PrismaClientValidationError('bad', { clientVersion: 't' })],
    ['P2023', new Prisma.PrismaClientKnownRequestError('conv', { code: 'P2023', clientVersion: 't' })],
    ['P2020', new Prisma.PrismaClientKnownRequestError('range', { code: 'P2020', clientVersion: 't' })],
  ])('kursor bilan %s → 400 VALIDATION', async (_name, error) => {
    const service = serviceFailingWith(error);
    const err = await service.list('c1', 'u1', { cursor }).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(BadRequestException);
    expect((err as BadRequestException).getResponse()).toMatchObject({ code: 'VALIDATION', message: 'cursor: invalid' });
  });

  it('kursorsiz so\'rovda xuddi shu xato 400 ga aylantirilmaydi (haqiqiy server xatosi)', async () => {
    const error = new Prisma.PrismaClientValidationError('bad', { clientVersion: 't' });
    await expect(serviceFailingWith(error).list('c1', 'u1', {})).rejects.toBe(error);
  });

  it('kursor bilan ham ulanish xatosi (P1001) 400 emas', async () => {
    const error = new Prisma.PrismaClientKnownRequestError('down', { code: 'P1001', clientVersion: 't' });
    await expect(serviceFailingWith(error).list('c1', 'u1', { cursor })).rejects.toBe(error);
  });
});
