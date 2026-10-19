// Bir marta: test bazasiga barcha migratsiyalarni qo'llash (bo'sh bazada
// migratsiya zanjiri ham shu yerda tekshiriladi).

import { execSync } from 'node:child_process';
import path from 'node:path';

export default async function globalSetup(): Promise<void> {
  require('./setup-env');
  execSync('npx prisma migrate deploy', {
    cwd: path.resolve(__dirname, '../..'),
    env: process.env,
    stdio: 'pipe',
  });
}
