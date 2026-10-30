import type { RegionId } from '@/data/reference/regions';
import { readPref, removePref, writePref } from '@/lib/prefs';
import { ROLE_KEYS, type RoleKey } from './permissions';

/** Kirgan foydalanuvchi (demo: localStorage; haqiqiy versiyada — JWT). */
export type Session = {
  username: string;
  role: RoleKey;
  /** REGIONAL uchun hudud; NATIONAL uchun null. */
  regionId: RegionId | null;
  loggedInAt: string;
};

const KEY = 'session';
type Listener = () => void;
const listeners = new Set<Listener>();
let current: Session | null | undefined;

function isSession(value: unknown): value is Session {
  if (!value || typeof value !== 'object') return false;
  const v = value as Record<string, unknown>;
  return (
    typeof v.username === 'string' &&
    typeof v.role === 'string' &&
    (ROLE_KEYS as readonly string[]).includes(v.role) &&
    (v.regionId === null || typeof v.regionId === 'string')
  );
}

export function getSession(): Session | null {
  if (current === undefined) {
    const stored = readPref<unknown>(KEY);
    current = isSession(stored) ? stored : null;
  }
  return current;
}

export function setSession(next: Session | null): void {
  if (next) writePref(KEY, next);
  else removePref(KEY);
  current = next;
  for (const l of listeners) l();
}

export function subscribeSession(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

/** Faqat testlar uchun. */
export function __setSessionForTests(next: Session | null): void {
  current = next;
}
