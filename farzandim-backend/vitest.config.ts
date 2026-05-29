import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: false,
    environment: 'node',
    include: ['tests/**/*.test.ts'],
    // H9 — config/env.ts (Zod strict + process.exit) test'da halok bo'lmasligi
    // uchun barcha majburiy env o'zgaruvchilarini shu yerda ta'minlaymiz.
    env: {
      NODE_ENV: 'development',
      DATABASE_URL: 'postgresql://test:test@localhost:5432/farzandim_test',
      TELEGRAM_BOT_TOKEN: '1234567890:TEST-BOT-TOKEN-AAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      TELEGRAM_BOT_USERNAME: 'farzandim_test_bot',
      JWT_ACCESS_SECRET: 'test-jwt-access-secret-at-least-32-chars',
      JWT_REFRESH_SECRET: 'test-jwt-refresh-secret-at-least-32-chars',
      ADMIN_JWT_ACCESS_SECRET: 'test-admin-jwt-access-secret-32-chars-min',
      ADMIN_JWT_REFRESH_SECRET: 'test-admin-jwt-refresh-secret-32-chars-min',
      MINIO_ENDPOINT: 'http://localhost:9000',
      MINIO_ACCESS_KEY: 'test-minio-key',
      MINIO_SECRET_KEY: 'test-minio-secret',
      MINIO_PUBLIC_URL: 'http://localhost:9000',
    },
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      include: ['src/**/*.ts'],
      exclude: [
        'src/server.ts',
        'src/lib/prisma.ts',
        'src/config/env.ts',
        'src/lib/fcm.ts',
        'src/lib/realtime.ts',
      ],
    },
  },
});
