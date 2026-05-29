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

  // application/x-www-form-urlencoded parser is auto-registered by NestJS Fastify
  // adapter (registerUrlencodedContentParser). No need for @fastify/formbody.
  // Click webhook receives parsed body via @Body() automatically.

  // ── CORS ──
  const corsOrigins = config
    .get('CORS_ORIGINS', { infer: true })
    .split(',')
    .map((o: string) => o.trim())
    .filter(Boolean);

  app.enableCors({
    origin: corsOrigins,
    credentials: true,
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
