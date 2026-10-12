import type { RoleKey } from '@/data/contracts';
import { readPref, removePref, writePref } from '@/lib/prefs';

/** Kirgan foydalanuvchi (demo: localStorage; haqiqiy: JWT). */
export type Session = { staffId: string; username: string; role: RoleKey; loggedInAt: string };

const KEY = 'session';
type Listener = () => void;
const listeners = new Set<Listener>();
let current: Session | null | undefined;

function isSession(value: unknown): value is Session {
  if (!value || typeof value !== 'object') return false;
  const v = value as Record<string, unknown>;
  return typeof v.staffId === 'string' && typeof v.username === 'string' && typeof v.role === 'string';
}

export function getSession(): Session | null {
  if (current === undefined) {
    const stored = readPref<unknown>(KEY);
    current = isSession(stored) ? stored : null;
  }
  return current;
}

export function setSession(next: Session | null): void {
  current = next;
  if (next) writePref(KEY, next);
  else removePref(KEY);
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
