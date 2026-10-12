import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { DEMO_ACCOUNTS } from '@/auth/demo-accounts';
import {
  __resetSessionCacheForTests,
  getSession,
  getSessionScope,
  getSharedSession,
  type Session,
  setSession,
  subscribeSession,
} from '@/auth/session';
import { signIn } from '@/auth/sign-in';
import { __setClockForTests } from '../clock';
import { setLatencyEnabled } from '../context';
import { __resetForTests, getTables } from '../db';

/** Node'da Web Storage yo'q — xotiradagi o'rinbosar. */
function memoryStorage(): Storage {
  const map = new Map<string, string>();
  return {
    get length() {
      return map.size;
    },
    clear: () => map.clear(),
    getItem: (k) => map.get(k) ?? null,
    key: (i) => [...map.keys()][i] ?? null,
    removeItem: (k) => void map.delete(k),
    setItem: (k, v) => void map.set(k, String(v)),
  };
}

const win = { localStorage: memoryStorage(), sessionStorage: memoryStorage() };

function session(username: string): Session {
  const account = DEMO_ACCOUNTS.find((a) => a.username === username);
  if (!account) throw new Error(username);
  return { staffId: account.staffId, username, role: account.role, loggedInAt: '2026-10-12T08:00:00.000Z' };
}

/** Yangi tab: umumiy localStorage qoladi, sessionStorage — bo'sh. */
function openNewTab(): void {
  win.sessionStorage = memoryStorage();
  __resetSessionCacheForTests();
}

describe('sessiya: tab ustunligi va umumiy sessiya', () => {
  beforeEach(() => {
    win.localStorage = memoryStorage();
    win.sessionStorage = memoryStorage();
    vi.stubGlobal('window', win);
    __resetSessionCacheForTests();
  });

  afterEach(() => {
    __resetSessionCacheForTests();
    vi.unstubAllGlobals();
  });

  it('umumiy sessiya barcha tablarda ko\'rinadi', () => {
    setSession(session('direktor'));
    expect(getSessionScope()).toBe('shared');
    openNewTab();
    expect(getSession()?.username).toBe('direktor');
    expect(getSessionScope()).toBe('shared');
  });

  it('tab sessiyasi faqat shu tabda ustun; boshqa tab umumiyni ko\'radi', () => {
    setSession(session('direktor'));
    setSession(session('navbatchi'), 'tab');
    expect(getSession()?.username).toBe('navbatchi');
    expect(getSessionScope()).toBe('tab');
    expect(getSharedSession()?.username).toBe('direktor');
    // Qayta yuklash (shu tab): tab sessiyasi saqlanadi.
    __resetSessionCacheForTests();
    expect(getSession()?.username).toBe('navbatchi');
    openNewTab();
    expect(getSession()?.username).toBe('direktor');
  });

  it('umumiy yozuv tab sessiyasini tozalaydi; chiqish — ikkalasini', () => {
    setSession(session('direktor'));
    setSession(session('psixolog'), 'tab');
    setSession(session('admin'));
    __resetSessionCacheForTests();
    expect(getSession()?.username).toBe('admin');
    expect(getSessionScope()).toBe('shared');

    setSession(session('psixolog'), 'tab');
    setSession(null);
    __resetSessionCacheForTests();
    expect(getSession()).toBeNull();
    expect(getSharedSession()).toBeNull();
  });

  it('subscribeSession har o\'zgarishda chaqiriladi', () => {
    const listener = vi.fn();
    const unsubscribe = subscribeSession(listener);
    setSession(session('direktor'));
    setSession(session('navbatchi'), 'tab');
    setSession(null);
    unsubscribe();
    setSession(session('admin'));
    expect(listener).toHaveBeenCalledTimes(3);
  });
});

describe('signIn: audit va sessiya doirasi', () => {
  beforeEach(() => {
    win.localStorage = memoryStorage();
    win.sessionStorage = memoryStorage();
    vi.stubGlobal('window', win);
    setLatencyEnabled(false);
    __resetForTests();
    __setClockForTests({ mode: 'SCENARIO', scenarioDate: '2026-10-12', scenarioStartMinute: 10 * 60, realStartedAt: Date.now(), speed: 1 });
    __resetSessionCacheForTests();
  });

  afterEach(() => {
    __resetSessionCacheForTests();
    __setClockForTests(null);
    __resetForTests();
    vi.unstubAllGlobals();
  });

  it('oddiy kirish: auth.login va umumiy sessiya', () => {
    const director = DEMO_ACCOUNTS.find((a) => a.role === 'DIRECTOR');
    if (!director) throw new Error('no director');
    signIn(director, 'shared');
    expect(getSessionScope()).toBe('shared');
    expect(getTables().audit.at(-1)).toMatchObject({ action: 'auth.login', actorId: director.staffId });
  });

  it('kiosk demo: navbatchi tab sessiyasi, auditda kim ochgani', () => {
    const director = DEMO_ACCOUNTS.find((a) => a.role === 'DIRECTOR');
    const duty = DEMO_ACCOUNTS.find((a) => a.role === 'DUTY');
    if (!director || !duty) throw new Error('no accounts');
    signIn(director, 'shared');
    signIn(duty, 'tab', { action: 'auth.kiosk.demo', by: { staffId: director.staffId, username: director.username } });
    expect(getSession()?.role).toBe('DUTY');
    expect(getSharedSession()?.role).toBe('DIRECTOR');
    expect(getTables().audit.at(-1)).toMatchObject({ action: 'auth.kiosk.demo', actorId: director.staffId, entityId: duty.staffId });
  });
});
