import { RouteConfig } from '@nestjs/platform-fastify';
import type { FastifyInstance } from 'fastify';

/**
 * Endpoint o'z so'rov hajmi chegarasini e'lon qiladi. Umumiy JSON chegarasi
 * (`JSON_BODY_LIMIT`) kichik — body autentifikatsiyadan OLDIN o'qiladi.
 * Kattaroq JSON kutadigan kam sonli endpoint shu dekorator bilan oshiradi.
 * Ishlashi uchun `applyRouteBodyLimits` marshrutlar ro'yxatga olinishidan
 * oldin chaqirilgan bo'lishi kerak (configure-app).
 */
export const BodyLimit = (bytes: number) => RouteConfig({ bodyLimit: bytes });

/** `@BodyLimit` qiymatini Fastify marshrutining `bodyLimit` iga ko'chiradi. */
export function applyRouteBodyLimits(fastify: FastifyInstance): void {
  fastify.addHook('onRoute', (route) => {
    const limit = (route.config as { bodyLimit?: unknown } | undefined)?.bodyLimit;
    if (typeof limit === 'number' && limit > 0) route.bodyLimit = limit;
  });
}
