import type { RoleKey } from '@/data/contracts';
import { PREF_PREFIX, readPref, removePref, writePref } from '@/lib/prefs';

/** Kirgan foydalanuvchi (demo: localStorage; haqiqiy: JWT). */
export type Session = { staffId: string; username: string; role: RoleKey; loggedInAt: string };

/**
 * `shared` — barcha tablar uchun umumiy (localStorage, oddiy kirish).
 * `tab` — faqat shu tab (sessionStorage): demo rol almashtirish va "navbatchi
 * sifatida" kiosk; boshqa tablar o'z rolida qoladi.
 */
export type SessionScope = 'shared' | 'tab';

const KEY = 'session';
const TAB_KEY = `${PREF_PREFIX}session:tab`;
type Listener = () => void;
const listeners = new Set<Listener>();
let current: Session | null | undefined;
let currentScope: SessionScope = 'shared';

function isSession(value: unknown): value is Session {
  if (!value || typeof value !== 'object') return false;
  const v = value as Record<string, unknown>;
  return typeof v.staffId === 'string' && typeof v.username === 'string' && typeof v.role === 'string';
}

function tabStorage(): Storage | null {
  if (typeof window === 'undefined') return null;
  try {
    return window.sessionStorage ?? null;
  } catch {
    return null;
  }
}

function readTab(): Session | null {
  try {
    const raw = tabStorage()?.getItem(TAB_KEY);
    if (!raw) return null;
    const parsed: unknown = JSON.parse(raw);
    return isSession(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function writeTab(next: Session | null): void {
  try {
    const storage = tabStorage();
    if (!storage) return;
    if (next) storage.setItem(TAB_KEY, JSON.stringify(next));
    else storage.removeItem(TAB_KEY);
  } catch {
    // bloklangan xotira — sessiya faqat xotirada qoladi
  }
}

function readShared(): Session | null {
  const stored = readPref<unknown>(KEY);
  return isSession(stored) ? stored : null;
}

/** Avval shu tabning sessiyasi, bo'lmasa — umumiy sessiya. */
export function getSession(): Session | null {
  if (current === undefined) {
    const tab = readTab();
    current = tab ?? readShared();
    currentScope = tab ? 'tab' : 'shared';
  }
  return current;
}

/** Joriy sessiya qayerdan: shu tab yoki umumiy. */
export function getSessionScope(): SessionScope {
  getSession();
  return currentScope;
}

/** Umumiy (localStorage) sessiya — kiosk "navbatchi sifatida" ochilishi uchun shart. */
export function getSharedSession(): Session | null {
  return readShared();
}

/**
 * `shared` yozuv tab sessiyasini ham tozalaydi (oddiy kirish hammasidan ustun);
 * `null` (chiqish) — ikkalasini ham.
 */
export function setSession(next: Session | null, scope: SessionScope = 'shared'): void {
  if (!next) {
    writeTab(null);
    removePref(KEY);
    currentScope = 'shared';
  } else if (scope === 'tab') {
    writeTab(next);
    currentScope = 'tab';
  } else {
    writeTab(null);
    writePref(KEY, next);
    currentScope = 'shared';
  }
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
  currentScope = 'shared';
}

/** Faqat testlar uchun — keyingi `getSession` xotiradan qayta o'qiydi ("yangi tab"). */
export function __resetSessionCacheForTests(): void {
  current = undefined;
  currentScope = 'shared';
}
