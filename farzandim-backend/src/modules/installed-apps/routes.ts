import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { authGuard } from '../../middleware/auth';
import { prisma } from '../../lib/prisma';
import { writeAudit } from '../../lib/audit';
import { BUCKETS, uploadFile, getDownloadUrl } from '../../lib/minio';

// Installed apps + App usage:
//   - Bola App har 24 soatda installed apps batch yuboradi (upsert)
//   - Bola App har soatda app_usage stats yuboradi (foreground ms, open count)
//   - Parent dashboard'da ko'radi (xushyorlik, App restrictions tuzish uchun)
//
// Icon flow (Sprint 4.4.25+):
//   - POST batch: app.iconBase64 → Backend decode → MinIO upload → iconPath upsert
//   - GET batch: iconPath bo'lsa, signed URL (iconUrl, 1h TTL) qaytariladi

const MAX_ICON_SIZE_BYTES = 50 * 1024; // 50 KB per icon
const ICON_SIGNED_URL_TTL = 3600; // 1 soat

const installedAppSchema = z.object({
  packageName: z.string().min(1).max(255),
  appName: z.string().min(1).max(255),
  versionName: z.string().max(50).optional(),
  versionCode: z.number().int().optional(),
  installSource: z.string().max(50).optional(),
  iconPath: z.string().max(500).optional(),       // Eski Flutter side ham yuborishi mumkin
  iconBase64: z.string().max(80_000).optional(),  // ~50 KB binary = ~67 KB base64, xavfsiz 80K
  isSystem: z.boolean().default(false),
});

const installedAppsBatchSchema = z.object({
  apps: z.array(installedAppSchema).min(1).max(500),
});

const appUsageEntrySchema = z.object({
  packageName: z.string().min(1).max(255),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD'),
  foregroundMs: z.number().int().min(0),
  lastUsedAt: z.string().datetime().optional(),
  openCount: z.number().int().min(0).default(0),
});

const appUsageBatchSchema = z.object({
  entries: z.array(appUsageEntrySchema).min(1).max(500),
});

const usageQuerySchema = z.object({
  from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  packageName: z.string().max(255).optional(),
  limit: z.coerce.number().int().min(1).max(1000).default(500),
});

/**
 * Base64 string (data URL yoki raw)'dan Buffer.
 * Data URL format'i: "data:image/png;base64,iVBORw0..." — prefix avtomatik strip.
 */
function decodeIconBase64(raw: string): { buffer: Buffer; mime: string } | null {
  try {
    let data = raw;
    let mime = 'image/png';
    if (raw.startsWith('data:')) {
      const m = /^data:([^;]+);base64,(.+)$/.exec(raw);
      if (!m) return null;
      mime = m[1];
      data = m[2];
    }
    const buffer = Buffer.from(data, 'base64');
    return { buffer, mime };
  } catch {
    return null;
  }
}

/**
 * Sanitize packageName for MinIO key (no slashes, max 200).
 * com.youtube → com.youtube; com.foo/bar → com.foo_bar (xavfsiz)
 */
function sanitizePackageKey(packageName: string): string {
  return packageName.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 200);
}

export const installedAppsRoutes: FastifyPluginAsync = async (fastify) => {
  fastify.addHook('preHandler', authGuard);

  /**
   * POST /api/children/:childId/installed-apps — batch upsert (child sends)
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/installed-apps',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.childUserId !== userId && child.parentId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const parsed = installedAppsBatchSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const now = new Date();

      // Birinchi: iconBase64 keladi bo'lsa MinIO'ga upload (parallel).
      // Har app uchun yangi iconPath (MinIO upload muvaffaqiyatli bo'lsa).
      let iconsUploaded = 0;
      let iconsRejected = 0;
      const iconUploads = await Promise.allSettled(
        parsed.data.apps.map(async (app) => {
          if (!app.iconBase64) return { packageName: app.packageName, iconPath: app.iconPath };

          const decoded = decodeIconBase64(app.iconBase64);
          if (!decoded) {
            iconsRejected++;
            return { packageName: app.packageName, iconPath: app.iconPath };
          }
          if (decoded.buffer.length > MAX_ICON_SIZE_BYTES) {
            iconsRejected++;
            request.log.warn(
              { packageName: app.packageName, size: decoded.buffer.length },
              'icon too large, skipped',
            );
            return { packageName: app.packageName, iconPath: app.iconPath };
          }
          if (decoded.mime !== 'image/png') {
            iconsRejected++;
            request.log.warn(
              { packageName: app.packageName, mime: decoded.mime },
              'icon mime not png, skipped',
            );
            return { packageName: app.packageName, iconPath: app.iconPath };
          }

          const key = `icons/${childId}/${sanitizePackageKey(app.packageName)}.png`;
          try {
            await uploadFile(BUCKETS.appIcons, key, decoded.buffer, 'image/png');
            iconsUploaded++;
            return { packageName: app.packageName, iconPath: key };
          } catch (err) {
            iconsRejected++;
            request.log.error({ err, key }, 'icon MinIO upload failed');
            return { packageName: app.packageName, iconPath: app.iconPath };
          }
        }),
      );

      // Map packageName → final iconPath (uploaded yangi yoki eski)
      const iconPathByPkg = new Map<string, string | undefined>();
      for (const r of iconUploads) {
        if (r.status === 'fulfilled') {
          iconPathByPkg.set(r.value.packageName, r.value.iconPath);
        }
      }

      const ops = parsed.data.apps.map((app) => {
        const iconPath = iconPathByPkg.get(app.packageName) ?? app.iconPath;
        return prisma.installedApp.upsert({
          where: { childId_packageName: { childId, packageName: app.packageName } },
          update: {
            appName: app.appName,
            versionName: app.versionName,
            versionCode: app.versionCode,
            installSource: app.installSource,
            iconPath,
            isSystem: app.isSystem,
            lastSeenAt: now,
          },
          create: {
            childId,
            packageName: app.packageName,
            appName: app.appName,
            versionName: app.versionName,
            versionCode: app.versionCode,
            installSource: app.installSource,
            iconPath,
            isSystem: app.isSystem,
          },
        });
      });

      await prisma.$transaction(ops);

      await writeAudit(request, 'installed_app', 'BATCH_UPSERT', childId, {
        count: parsed.data.apps.length,
        iconsUploaded,
        iconsRejected,
      });

      return reply.code(201).send({
        ok: true,
        upserted: parsed.data.apps.length,
        iconsUploaded,
        iconsRejected,
      });
    },
  );

  /**
   * GET /api/children/:childId/installed-apps
   */
  fastify.get<{
    Params: { childId: string };
    Querystring: { includeSystem?: string };
  }>('/children/:childId/installed-apps', async (request, reply) => {
    const userId = request.user!.userId;
    const { childId } = request.params;
    const includeSystem = request.query.includeSystem === 'true';

    const child = await prisma.child.findUnique({ where: { id: childId } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const apps = await prisma.installedApp.findMany({
      where: { childId, ...(includeSystem ? {} : { isSystem: false }) },
      orderBy: { appName: 'asc' },
    });

    // iconPath bo'lsa signed URL (iconUrl) — Parent Image.network ishlatadi.
    // Promise.all 100 ta app uchun ~30-100ms (signed URL sof string operatsiya).
    const withIconUrls = await Promise.all(
      apps.map(async (app) => {
        let iconUrl: string | null = null;
        if (app.iconPath) {
          try {
            iconUrl = await getDownloadUrl(BUCKETS.appIcons, app.iconPath, ICON_SIGNED_URL_TTL);
          } catch (err) {
            request.log.warn({ err, iconPath: app.iconPath }, 'iconUrl presign failed');
          }
        }
        return { ...app, iconUrl };
      }),
    );

    return reply.send({ apps: withIconUrls, count: withIconUrls.length });
  });

  /**
   * POST /api/children/:childId/app-usage — batch upsert (child sends daily)
   */
  fastify.post<{ Params: { childId: string } }>(
    '/children/:childId/app-usage',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.childUserId !== userId && child.parentId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      const parsed = appUsageBatchSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid payload', details: parsed.error.format() });
      }

      const ops = parsed.data.entries.map((entry) => {
        const dateObj = new Date(`${entry.date}T00:00:00.000Z`);
        return prisma.appUsage.upsert({
          where: {
            childId_packageName_date: {
              childId,
              packageName: entry.packageName,
              date: dateObj,
            },
          },
          update: {
            foregroundMs: BigInt(entry.foregroundMs),
            lastUsedAt: entry.lastUsedAt ? new Date(entry.lastUsedAt) : undefined,
            openCount: entry.openCount,
          },
          create: {
            childId,
            packageName: entry.packageName,
            date: dateObj,
            foregroundMs: BigInt(entry.foregroundMs),
            lastUsedAt: entry.lastUsedAt ? new Date(entry.lastUsedAt) : undefined,
            openCount: entry.openCount,
          },
        });
      });

      await prisma.$transaction(ops);

      await writeAudit(request, 'app_usage', 'BATCH_UPSERT', childId, {
        count: parsed.data.entries.length,
      });

      return reply.code(201).send({ ok: true, upserted: parsed.data.entries.length });
    },
  );

  /**
   * GET /api/children/:childId/app-usage?from=YYYY-MM-DD&to=...&packageName=...
   */
  fastify.get<{
    Params: { childId: string };
    Querystring: { from?: string; to?: string; packageName?: string; limit?: number };
  }>('/children/:childId/app-usage', async (request, reply) => {
    const userId = request.user!.userId;
    const { childId } = request.params;

    const child = await prisma.child.findUnique({ where: { id: childId } });
    if (!child) return reply.code(404).send({ error: 'Child not found' });
    if (child.parentId !== userId && child.childUserId !== userId) {
      return reply.code(403).send({ error: 'Forbidden' });
    }

    const parsed = usageQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'Invalid query', details: parsed.error.format() });
    }

    const { from, to, packageName, limit } = parsed.data;

    const usage = await prisma.appUsage.findMany({
      where: {
        childId,
        ...(packageName && { packageName }),
        ...(from || to
          ? {
              date: {
                ...(from && { gte: new Date(`${from}T00:00:00.000Z`) }),
                ...(to && { lte: new Date(`${to}T00:00:00.000Z`) }),
              },
            }
          : {}),
      },
      orderBy: [{ date: 'desc' }, { foregroundMs: 'desc' }],
      take: limit,
    });

    // BigInt → number for JSON (foregroundMs < 2^53 — safe)
    const serialized = usage.map((u) => ({
      ...u,
      foregroundMs: Number(u.foregroundMs),
    }));

    return reply.send({ usage: serialized, count: serialized.length });
  });

  /**
   * GET /api/children/:childId/app-usage/weekly
   * Oxirgi 7 kunlik kunlik jami foreground vaqt — Parent analitika grafigi uchun.
   */
  fastify.get<{ Params: { childId: string } }>(
    '/children/:childId/app-usage/weekly',
    async (request, reply) => {
      const userId = request.user!.userId;
      const { childId } = request.params;

      const child = await prisma.child.findUnique({ where: { id: childId } });
      if (!child) return reply.code(404).send({ error: 'Child not found' });
      if (child.parentId !== userId && child.childUserId !== userId) {
        return reply.code(403).send({ error: 'Forbidden' });
      }

      // Oxirgi 7 kun (UTC sanalar), eng eskidan eng yangiga.
      const today = new Date();
      const dayKeys: string[] = [];
      for (let i = 6; i >= 0; i -= 1) {
        const d = new Date(
          Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() - i),
        );
        dayKeys.push(d.toISOString().slice(0, 10)); // YYYY-MM-DD
      }
      const fromDate = new Date(`${dayKeys[0]}T00:00:00.000Z`);

      const rows = await prisma.appUsage.findMany({
        where: { childId, date: { gte: fromDate } },
        select: { date: true, foregroundMs: true },
      });

      // Kun bo'yicha jami foreground vaqtni hisoblaymiz.
      const totalsByDay = new Map<string, number>();
      for (const key of dayKeys) totalsByDay.set(key, 0);
      for (const row of rows) {
        const key = row.date.toISOString().slice(0, 10);
        if (totalsByDay.has(key)) {
          totalsByDay.set(key, (totalsByDay.get(key) ?? 0) + Number(row.foregroundMs));
        }
      }

      const days = dayKeys.map((date) => {
        const totalMs = totalsByDay.get(date) ?? 0;
        return { date, totalMs, totalMinutes: Math.round(totalMs / 60000) };
      });
      const weekTotalMs = days.reduce((sum, d) => sum + d.totalMs, 0);

      return reply.send({
        days,
        weekTotalMs,
        weekTotalMinutes: Math.round(weekTotalMs / 60000),
      });
    },
  );
};
