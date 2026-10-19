// E2E: production quvuri bilan bir xil sozlangan Nest ilovasi (Fastify),
// tashqi xizmatlar (MinIO, FCM) soxta, cron vazifalar to'xtatilgan.

import { INestApplication } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import { SchedulerRegistry } from '@nestjs/schedule';
import { Test } from '@nestjs/testing';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap/configure-app';
import { PrismaService } from '../../src/common/database/prisma.service';
import { FcmService } from '../../src/common/fcm/fcm.service';
import { StorageService } from '../../src/common/storage/storage.service';
import { FakeFcm, fakeStorage } from './fakes';

export interface TestApp {
  app: NestFastifyApplication;
  prisma: PrismaService;
  fcm: FakeFcm;
  jwt: JwtService;
  close(): Promise<void>;
}

export async function createTestApp(): Promise<TestApp> {
  const fcm = new FakeFcm();
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(FcmService)
    .useValue(fcm)
    .overrideProvider(StorageService)
    .useValue(fakeStorage())
    .compile();

  const app = moduleRef.createNestApplication<NestFastifyApplication>(
    new FastifyAdapter(),
    { logger: ['error', 'warn'] },
  );
  await configureApp(app, { swagger: false });
  await app.init();
  await app.getHttpAdapter().getInstance().ready();
  stopCronJobs(app);
  const prisma = app.get(PrismaService);
  fcm.attachPrisma(prisma);

  return {
    app,
    prisma,
    fcm,
    jwt: app.get(JwtService),
    close: () => app.close(),
  };
}

function stopCronJobs(app: INestApplication): void {
  const registry = app.get(SchedulerRegistry);
  for (const job of registry.getCronJobs().values()) job.stop();
  for (const name of registry.getIntervals()) registry.deleteInterval(name);
}
