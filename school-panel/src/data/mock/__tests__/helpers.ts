import { DEMO_ACCOUNTS } from '@/auth/demo-accounts';
import { __setSessionForTests } from '@/auth/session';
import type { RoleKey } from '@/data/contracts';
import { __setClockForTests } from '../clock';
import { setLatencyEnabled } from '../context';
import { __resetForTests, getDb } from '../db';

/** Testlar uchun: kechikishsiz, yangi seed, belgilangan demo vaqti (2026-10-12, dushanba). */
export function freshDb(): void {
  setLatencyEnabled(false);
  __resetForTests();
  __setClockForTests({ mode: 'SCENARIO', scenarioDate: '2026-10-12', scenarioStartMinute: 10 * 60, realStartedAt: Date.now(), speed: 1 });
  getDb();
}

/** Demo hisob bilan "kirish" (DIRECTOR | ADMIN | HOMEROOM | PSYCHOLOGIST | DUTY). */
export function loginAs(role: Exclude<RoleKey, 'TEACHER'>): void {
  const account = DEMO_ACCOUNTS.find((a) => a.role === role);
  if (!account) throw new Error(role);
  __setSessionForTests({ staffId: account.staffId, username: account.username, role: account.role, loggedInAt: new Date().toISOString() });
}
