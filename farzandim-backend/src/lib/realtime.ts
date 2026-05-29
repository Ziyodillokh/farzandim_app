import { Server as IOServer, Socket } from 'socket.io';
import type { FastifyInstance } from 'fastify';
import { verifyAccessToken } from '../modules/auth/jwt';
import { prisma } from './prisma';
import { corsOrigins } from '../config/env';

// Real-time event'lar socket.io orqali. Mobile app (Sprint 4.4 reja) `socket_io_client`
// paketi bilan ulanadi. JWT handshake — `socket.handshake.auth.token`.
// Rooms:
//   user:<userId>   — connect paytida avtomatik join. User-specific event'lar shu yerga
//   child:<childId> — client `join:child` emit qilib qo'shiladi (auth check bilan)

let io: IOServer | null = null;

interface SocketData {
  userId: string;
  role: 'PARENT' | 'CHILD';
}

export function initRealtime(fastify: FastifyInstance): void {
  if (io) {
    fastify.log.warn('initRealtime called twice');
    return;
  }

  io = new IOServer(fastify.server, {
    cors: { origin: corsOrigins, credentials: true },
    serveClient: false,
    // Mobile + browser uchun ikkala transport
    transports: ['websocket', 'polling'],
  });

  // JWT handshake middleware
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) return next(new Error('Missing auth token'));
    try {
      const payload = verifyAccessToken(token);
      (socket.data as SocketData).userId = payload.userId;
      (socket.data as SocketData).role = payload.role;
      next();
    } catch {
      next(new Error('Invalid or expired access token'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const { userId, role } = socket.data as SocketData;
    socket.join(`user:${userId}`);

    fastify.log.info({ userId, role, socketId: socket.id }, 'socket connected');

    // Client child room'ga qo'shilmoqchi
    socket.on(
      'join:child',
      async (childId: unknown, ack?: (ok: boolean, error?: string) => void) => {
        if (typeof childId !== 'string') {
          ack?.(false, 'childId must be string');
          return;
        }
        try {
          const child = await prisma.child.findUnique({ where: { id: childId } });
          if (!child) {
            ack?.(false, 'child not found');
            return;
          }
          if (child.parentId !== userId && child.childUserId !== userId) {
            ack?.(false, 'forbidden');
            return;
          }
          await socket.join(`child:${childId}`);
          ack?.(true);
        } catch (err) {
          fastify.log.error({ err, childId, userId }, 'join:child error');
          ack?.(false, 'internal error');
        }
      },
    );

    socket.on('leave:child', async (childId: unknown, ack?: (ok: boolean) => void) => {
      if (typeof childId !== 'string') {
        ack?.(false);
        return;
      }
      await socket.leave(`child:${childId}`);
      ack?.(true);
    });

    socket.on('disconnect', (reason) => {
      fastify.log.debug({ userId, socketId: socket.id, reason }, 'socket disconnected');
    });
  });

  fastify.log.info('Realtime (socket.io) initialized');
}

/**
 * Bitta foydalanuvchining barcha qurilmalariga event yuborish.
 */
export function emitToUser(userId: string, event: string, payload: unknown): void {
  if (!io) return;
  io.to(`user:${userId}`).emit(event, payload);
}

/**
 * Bolaning room'idagi barcha ulanganlarga (parent + child) event yuborish.
 */
export function emitToChild(childId: string, event: string, payload: unknown): void {
  if (!io) return;
  io.to(`child:${childId}`).emit(event, payload);
}

/**
 * Test/admin uchun — ulangan socket'lar soni.
 */
export async function getConnectedCount(): Promise<number> {
  if (!io) return 0;
  const sockets = await io.fetchSockets();
  return sockets.length;
}

/**
 * Graceful shutdown (H10) — barcha socket ulanishlarini majburan uzadi.
 * Bu `fastify.close()` ning ochiq socket.io ulanishlarini kutib osilib
 * qolishini oldini oladi.
 */
export function closeRealtime(): void {
  if (!io) return;
  io.disconnectSockets(true);
  io = null;
}
