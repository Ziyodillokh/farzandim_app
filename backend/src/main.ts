import { NestFactory } from '@nestjs/core';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { ValidationPipe, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { EnvConfig } from './common/config/env.schema';

async function bootstrap() {
  const logger = new Logger('Bootstrap');

  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({
      bodyLimit: 100 * 1024 * 1024, // 100 MB
      forceCloseConnections: true,
    }),
  );

  const config = app.get(ConfigService<EnvConfig, true>);

  // ── Global prefix ──
  app.setGlobalPrefix('api');

  // ── Global validation pipe ──
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // ── Global exception filter ──
  app.useGlobalFilters(new GlobalExceptionFilter());

  // ── Swagger ──
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Farzandim API')
    .setVersion('2.0.0')
    .addBearerAuth(
      { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      'consumer-jwt',
    )
    .addBearerAuth(
      { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      'admin-jwt',
    )
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  // ── Fastify plugins ──
  await app.register(
    await import('@fastify/helmet').then((m) => m.default),
    { contentSecurityPolicy: false },
  );

  await app.register(
    await import('@fastify/cookie').then((m) => m.default),
  );

  // Multipart/form-data — Fastify adapter ostida Multer (platform-express)
  // ISHLAMAYDI. Shu plugin avatar/video/voice/photo upload'larini parse qiladi.
  // req.file() / req.parts() orqali fayllar o'qiladi. fileSize bodyLimit bilan
  // mos (100 MB); har endpoint o'z service'ida kichikroq cheklov qo'yadi.
  await app.register(
    await import('@fastify/multipart').then((m) => m.default),
    { limits: { fileSize: 100 * 1024 * 1024 } },
  );

  // application/x-www-form-urlencoded parser is auto-registered by NestJS Fastify
  // adapter (registerUrlencodedContentParser). No need for @fastify/formbody.
  // Click webhook receives parsed body via @Body() automatically.

  // ── CORS ──
  const corsOrigins = config
    .get('CORS_ORIGINS', { infer: true })
    .split(',')
    .map((o: string) => o.trim())
    .filter(Boolean);

  // Lokal/LAN origin'lar (localhost + xususiy IP diapazonlari) — dev/preview
  // uchun istalgan portda ruxsat etiladi. Shu sabab telefon hotspoti yoki
  // router IP'si o'zgarsa ham CORS qayta sozlanmaydi.
  const lanOriginRegex =
    /^https?:\/\/(localhost|127\.0\.0\.1|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})(:\d+)?$/;

  app.enableCors({
    origin: (origin, cb) => {
      if (
        !origin ||
        corsOrigins.includes(origin) ||
        lanOriginRegex.test(origin)
      ) {
        cb(null, true);
      } else {
        cb(null, false);
      }
    },
    credentials: true,
    methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    exposedHeaders: ['Content-Disposition'],
  });

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
