import { NestFactory } from '@nestjs/core';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { configureApp } from './bootstrap/configure-app';
import { EnvConfig } from './common/config/env.schema';
import { resolveTrustProxy } from './common/helpers/trust-proxy';

async function bootstrap() {
  const logger = new Logger('Bootstrap');

  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({
      bodyLimit: 100 * 1024 * 1024, // 100 MB
      forceCloseConnections: true,
      // nginx orqasida — FAQAT lokal proksiga ishonamiz, shunda `request.ip`
      // klient soxtalashtira olmaydigan haqiqiy IP bo'ladi (rate-limit, admin
      // IP allowlist, webhook guard). Batafsil: helpers/trust-proxy.ts.
      trustProxy: resolveTrustProxy(process.env.TRUST_PROXY),
    }),
  );

  await configureApp(app);
  const config = app.get(ConfigService<EnvConfig, true>);

  // ── Shutdown hooks ──
  app.enableShutdownHooks();

  // ── Listen ──
  const port = config.get('PORT', { infer: true });
  const host = config.get('HOST', { infer: true });

  await app.listen(port, host);
  logger.log(`Farzandim API running on http://${host}:${port}`);
  logger.log(`Swagger docs: http://${host}:${port}/api/docs`);
}

bootstrap();
