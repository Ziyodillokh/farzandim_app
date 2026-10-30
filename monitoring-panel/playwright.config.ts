import { defineConfig, devices } from '@playwright/test';

/** E2E: `npm run build` dan keyin `out/` prod nginx kabi (`/monitoring` ostida) xizmat qilinadi. */
const PORT = 4502;
const IS_CI = Boolean(process.env.CI);

export default defineConfig({
  testDir: './e2e',
  timeout: 240_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  workers: IS_CI ? 2 : 4,
  retries: IS_CI ? 1 : 0,
  reporter: IS_CI ? [['github'], ['list']] : 'list',
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    locale: 'uz-UZ',
    timezoneId: 'Asia/Tashkent',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } } }],
  webServer: {
    command: 'node scripts/serve-out.mjs',
    env: { PORT: String(PORT) },
    url: `http://127.0.0.1:${PORT}/monitoring/login/`,
    reuseExistingServer: !IS_CI,
  },
});
