import type { RoleKey } from '@/data/contracts';

/**
 * Demo hisoblar (TZ 2.2). Faqat demo uchun: parol brauzer kodida ko'rinadi.
 * Haqiqiy versiyada login backend (JWT + 2FA) orqali bo'ladi.
 */
export type DemoAccount = { username: string; password: string; staffId: string; role: RoleKey };

export const DEMO_ACCOUNTS: readonly DemoAccount[] = [
  { username: 'direktor', password: 'Direktor2026', staffId: 'stf-director', role: 'DIRECTOR' },
  { username: 'admin', password: 'Admin2026', staffId: 'stf-admin', role: 'ADMIN' },
  { username: 'sinf7a', password: 'Sinf2026', staffId: 'stf-homeroom-7a', role: 'HOMEROOM' },
  { username: 'psixolog', password: 'Psixolog2026', staffId: 'stf-psychologist', role: 'PSYCHOLOGIST' },
  { username: 'navbatchi', password: 'Navbatchi2026', staffId: 'stf-duty', role: 'DUTY' },
];

export function findDemoAccount(username: string, password: string): DemoAccount | null {
  const login = username.trim().toLowerCase();
  return DEMO_ACCOUNTS.find((a) => a.username === login && a.password === password) ?? null;
}
