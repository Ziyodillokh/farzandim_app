import { FastifyRequest, FastifyReply } from 'fastify';
import { verifyAccessToken, JwtPayload } from '../modules/auth/jwt';

declare module 'fastify' {
  interface FastifyRequest {
    user?: JwtPayload;
  }
}

export async function authGuard(request: FastifyRequest, reply: FastifyReply) {
  const authHeader = request.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return reply.code(401).send({ error: 'Missing or invalid Authorization header' });
  }
  
  const token = authHeader.slice(7);
  
  try {
    const payload = verifyAccessToken(token);
    request.user = payload;
  } catch (err) {
    return reply.code(401).send({ error: 'Invalid or expired access token' });
  }
}
