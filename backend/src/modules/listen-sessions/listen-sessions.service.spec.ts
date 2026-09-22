import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { ListenSessionsService } from './listen-sessions.service';

/**
 * Xavfsizlik testlari — jonli eshitish sessiyasini KIM boshlashi va
 * to'xtatishi mumkinligini pinlaydi.
 *
 * Eng muhim savol: begona odam boshqa oilaning bolasini tinglay oladimi?
 * Yo'q — quyida ataylab noto'g'ri foydalanuvchi bilan urinamiz.
 */
describe('ListenSessionsService — avtorizatsiya', () => {
  const PARENT = 'parent-user-1';
  const CHILD_USER = 'child-user-1';
  const OUTSIDER = 'outsider-user-9';
  const CHILD_ID = 'child-1';

  type PrismaMock = {
    child: { findUnique: jest.Mock };
    listenSession: {
      findUnique: jest.Mock;
      findMany: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
      updateMany: jest.Mock;
    };
  };

  let prisma: PrismaMock;
  let realtime: { emitToUser: jest.Mock; emitToChild: jest.Mock };
  let fcm: { sendPushToUser: jest.Mock };
  let audit: { log: jest.Mock };
  let service: ListenSessionsService;

  beforeEach(() => {
    prisma = {
      child: { findUnique: jest.fn() },
      listenSession: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
    };
    realtime = { emitToUser: jest.fn(), emitToChild: jest.fn() };
    fcm = { sendPushToUser: jest.fn().mockResolvedValue({ sent: 1 }) };
    audit = { log: jest.fn().mockResolvedValue(undefined) };
    service = new ListenSessionsService(
      prisma as never,
      realtime as never,
      fcm as never,
      audit as never,
    );
  });

  describe('start', () => {
    it('FAQAT ota-ona boshlay oladi — begona RAD etiladi', async () => {
      prisma.child.findUnique.mockResolvedValue({
        id: CHILD_ID,
        parentId: PARENT,
        childUserId: CHILD_USER,
      });
      await expect(service.start(CHILD_ID, OUTSIDER)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      expect(prisma.listenSession.create).not.toHaveBeenCalled();
      expect(fcm.sendPushToUser).not.toHaveBeenCalled();
    });

    it('bola ulanmagan bo\'lsa boshlab bo\'lmaydi', async () => {
      prisma.child.findUnique.mockResolvedValue({
        id: CHILD_ID,
        parentId: PARENT,
        childUserId: null,
      });
      await expect(service.start(CHILD_ID, PARENT)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
    });

    it('bola topilmasa 404', async () => {
      prisma.child.findUnique.mockResolvedValue(null);
      await expect(service.start(CHILD_ID, PARENT)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('ota-ona boshlaganda: sessiya yaratiladi + bola uyg\'otiladi', async () => {
      prisma.child.findUnique.mockResolvedValue({
        id: CHILD_ID,
        parentId: PARENT,
        childUserId: CHILD_USER,
      });
      prisma.listenSession.updateMany.mockResolvedValue({ count: 0 });
      prisma.listenSession.create.mockResolvedValue({
        id: 's1',
        childId: CHILD_ID,
        status: 'PENDING',
        startedAt: new Date(),
        endedAt: null,
        endedBy: null,
      });

      const res = await service.start(CHILD_ID, PARENT);

      expect(res.status).toBe('PENDING');
      // Bola qurilmasi uyg'otildi (data-only push).
      expect(fcm.sendPushToUser).toHaveBeenCalledWith(
        CHILD_USER,
        expect.objectContaining({
          dataOnly: true,
          data: expect.objectContaining({ type: 'listen_request', sessionId: 's1' }),
        }),
      );
      // Hisobdorlik yozuvi.
      expect(audit.log).toHaveBeenCalledWith(
        PARENT,
        'listen_session',
        'START',
        's1',
        undefined,
        undefined,
      );
    });
  });

  describe('end', () => {
    const activeSession = {
      id: 's1',
      parentId: PARENT,
      childId: CHILD_ID,
      status: 'ACTIVE',
      startedAt: new Date('2026-09-22T10:00:00Z'),
      endedAt: null,
      endedBy: null,
      child: { childUserId: CHILD_USER },
    };

    it('begona to\'xtata OLMAYDI', async () => {
      prisma.listenSession.findUnique.mockResolvedValue(activeSession);
      await expect(service.end('s1', OUTSIDER)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      expect(prisma.listenSession.update).not.toHaveBeenCalled();
    });

    it('BOLA o\'zi to\'xtata oladi (endedBy=child)', async () => {
      prisma.listenSession.findUnique.mockResolvedValue(activeSession);
      prisma.listenSession.update.mockResolvedValue({
        ...activeSession,
        status: 'ENDED',
        endedAt: new Date(),
        endedBy: 'child',
      });
      const res = await service.end('s1', CHILD_USER);
      expect(res.endedBy).toBe('child');
      // Ikkala tomonga ham "to'xtadi" signali (mikrofon o'chsin).
      expect(realtime.emitToUser).toHaveBeenCalledWith(
        CHILD_USER,
        'listen:ended',
        expect.objectContaining({ endedBy: 'child' }),
      );
    });

    it('ota-ona to\'xtata oladi (endedBy=parent)', async () => {
      prisma.listenSession.findUnique.mockResolvedValue(activeSession);
      prisma.listenSession.update.mockResolvedValue({
        ...activeSession,
        status: 'ENDED',
        endedAt: new Date(),
        endedBy: 'parent',
      });
      const res = await service.end('s1', PARENT);
      expect(res.endedBy).toBe('parent');
    });
  });
});
