import { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';
import { readFileSync } from 'fs';
import { join } from 'path';

// AppVersion modul — Flutter Parent + Child app'lar uchun yangilanish
// ma'lumotini qaytaradi. Auth talab qilinmaydi (app startup'da chaqiriladi).
//
// Konfiguratsiya manba: `config/app-versions.json` (git'da). Deploy paytida
// fayl o'qiladi va lazy-cache qilinadi. Faylni qayta yozish kerak — service
// restart majburiy emas (har request'da fayl re-read). Lekin xavfsizlik
// uchun in-memory cache + ETag yo'q (fayl o'lchami ~1 KB, har chaqiruv arzon).
//
// Flutter klient mantig'i:
//   currentVersion < minSupported → ForceUpdateDialog (block, Store link)
//   currentVersion < latest       → UpdateBanner dashboard'da (dismissable)
//   currentVersion >= latest      → hech narsa
//   isForceUpdate: true            → minSupported'dan qat'iy nazar block

const querySchema = z.object({
  app: z.enum(['parent', 'child']),
});

type PlatformInfo = {
  latest: string;
  minSupported: string;
  playStoreUrl?: string;
  appStoreUrl?: string;
  directApkUrl?: string;
};

type AppVersionEntry = {
  android: PlatformInfo;
  ios: PlatformInfo;
  releaseNotes: string;
  isForceUpdate: boolean;
};

type AppVersionsConfig = {
  parent: AppVersionEntry;
  child: AppVersionEntry;
};

const CONFIG_PATH = join(process.cwd(), 'config', 'app-versions.json');

function readConfig(): AppVersionsConfig {
  const raw = readFileSync(CONFIG_PATH, 'utf-8');
  return JSON.parse(raw) as AppVersionsConfig;
}

export const appVersionRoutes: FastifyPluginAsync = async (fastify) => {
  /**
   * GET /api/app/version?app=parent|child
   *
   * No auth (app startup'da chaqiriladi, foydalanuvchi hali login bo'lmagan
   * bo'lishi mumkin — masalan Welcome screen'da).
   *
   * Response 200:
   * {
   *   "android": { "latest", "minSupported", "playStoreUrl", "directApkUrl" },
   *   "ios":     { "latest", "minSupported", "appStoreUrl" },
   *   "releaseNotes": "...",
   *   "isForceUpdate": false
   * }
   *
   * Errors:
   *   400 — app query param noto'g'ri (faqat 'parent' yoki 'child')
   *   500 — config faylda xato (deploy issue)
   */
  fastify.get('/version', async (request, reply) => {
    const parseResult = querySchema.safeParse(request.query);
    if (!parseResult.success) {
      return reply.code(400).send({
        error: "app query param required (parent|child)",
        details: parseResult.error.flatten(),
      });
    }
    const { app } = parseResult.data;

    try {
      const config = readConfig();
      const entry = config[app];
      if (!entry) {
        return reply.code(500).send({ error: `Config entry missing: ${app}` });
      }
      return reply.send(entry);
    } catch (err) {
      request.log.error({ err }, 'app-version: config read failed');
      return reply.code(500).send({
        error: 'Configuration unavailable',
      });
    }
  });
};
