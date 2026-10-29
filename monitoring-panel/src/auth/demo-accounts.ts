import type { RegionId } from '@/data/reference/regions';
import type { RoleKey } from './permissions';

/**
 * Demo hisoblar. Faqat namoyish uchun: parol brauzer kodida ko'rinadi.
 * Haqiqiy versiyada kirish backend (JWT + 2FA) orqali bo'ladi.
 */
export type DemoAccount = {
  username: string;
  password: string;
  role: RoleKey;
  /** Viloyat roli uchun — hudud; respublika uchun null. */
  regionId: RegionId | null;
};

export const DEMO_ACCOUNTS: readonly DemoAccount[] = [
  { username: 'respublika', password: 'Respublika2026', role: 'NATIONAL', regionId: null },
  { username: 'samarqand', password: 'Samarqand2026', role: 'REGIONAL', regionId: 'UZ-SA' },
  { username: 'toshkent', password: 'Toshkent2026', role: 'REGIONAL', regionId: 'UZ-TK' },
];

export function findDemoAccount(username: string, password: string): DemoAccount | null {
  const login = username.trim().toLowerCase();
  return DEMO_ACCOUNTS.find((a) => a.username === login && a.password === password) ?? null;
}
