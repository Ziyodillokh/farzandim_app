import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../database/prisma.service';
import { JwtPayload } from '../interfaces/jwt-payload.interface';
import { EnvConfig } from '../config/env.schema';

@WebSocketGateway({
  cors: {
    origin: true,
    credentials: true,
  },
  transports: ['websocket', 'polling'],
})
export class RealtimeGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly config: ConfigService<EnvConfig, true>,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * JWT handshake: verify consumer access token on connection.
   */
  async handleConnection(client: Socket): Promise<void> {
    try {
      const token = client.handshake.auth?.token as string | undefined;
      if (!token) {
        client.disconnect();
        return;
      }

      const payload = this.jwtService.verify<JwtPayload>(token, {
        secret: this.config.get('JWT_ACCESS_SECRET', { infer: true }),
      });

      client.data.userId = payload.userId;
      client.data.role = payload.role;

      // Auto-join user-specific room
      await client.join(`user:${payload.userId}`);

      this.logger.log(
        `Socket connected: userId=${payload.userId}, role=${payload.role}, socketId=${client.id}`,
      );
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket): void {
    this.logger.debug(
      `Socket disconnected: userId=${client.data?.userId}, socketId=${client.id}`,
    );
  }

  /**
   * Client requests to join a child room (with family authorization check).
   */
  @SubscribeMessage('join:child')
  async handleJoinChild(
    @ConnectedSocket() client: Socket,
    @MessageBody() childId: string,
  ): Promise<{ ok: boolean; error?: string }> {
    if (typeof childId !== 'string') {
      return { ok: false, error: 'childId must be string' };
    }

    try {
      const child = await this.prisma.child.findUnique({
        where: { id: childId },
      });

      if (!child) {
        return { ok: false, error: 'child not found' };
      }

      const userId = client.data.userId as string;
      if (child.parentId !== userId && child.childUserId !== userId) {
        return { ok: false, error: 'forbidden' };
      }

      await client.join(`child:${childId}`);
      return { ok: true };
    } catch (err) {
      this.logger.error(`join:child error`, err);
      return { ok: false, error: 'internal error' };
    }
  }

  /**
   * Client requests to leave a child room.
   */
  @SubscribeMessage('leave:child')
  async handleLeaveChild(
    @ConnectedSocket() client: Socket,
    @MessageBody() childId: string,
  ): Promise<{ ok: boolean }> {
    if (typeof childId !== 'string') {
      return { ok: false };
    }

    await client.leave(`child:${childId}`);
    return { ok: true };
  }

  /**
   * Emit an event to all devices of a specific user.
   */
  emitToUser(userId: string, event: string, payload: unknown): void {
    this.server.to(`user:${userId}`).emit(event, payload);
  }

  /**
   * Emit an event to all connections in a child room.
   */
  emitToChild(childId: string, event: string, payload: unknown): void {
    this.server.to(`child:${childId}`).emit(event, payload);
  }
}
