import { FastifyReply, FastifyRequest } from 'fastify';
import { AdminJwtPayload, verifyAdminAccessToken } from '../modules/admin-auth/jwt';

declare module 'fastify' {
  interface FastifyRequest {
    staff?: AdminJwtPayload;
  }
}

/**
 * Guard for /api/admin/* routes. Verifies an admin JWT (separate audience
 * from the Telegram parent/child tokens — leaking a staff token never grants
 * consumer-API access and vice versa).
 */
export async function staffAuthGuard(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const header = request.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    reply.code(401).send({ error: 'Missing bearer token' });
    return;
  }
  const token = header.slice(7).trim();
  if (!token) {
    reply.code(401).send({ error: 'Empty bearer token' });
    return;
  }
  try {
    request.staff = verifyAdminAccessToken(token);
  } catch {
    reply.code(401).send({ error: 'Invalid or expired admin token' });
  }
}
