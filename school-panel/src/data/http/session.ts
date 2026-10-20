import { setSession, type Session } from '@/auth/session';
import type { RoleKey } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { API_BASE } from '@/data/source';
import { setAccessToken, setRefreshHandler, setSessionLostHandler } from './client';

/** Backend `/school/auth/me` javobi. */
export type HttpMe = {
  staff: { id: string; fullName: string; role: RoleKey; position: string; phone: string; email: string; username: string | null; photo: string | null; portrait: string | null };
  school: { id: string; code: string; name: string; shortName: string; logo: string | null };
  scope: 'SCHOOL' | 'OWN_CLASS';
  classIds: string[];
  permissions: string[];
  mustChangePassword: boolean;
  totpEnabled: boolean;
};

export type LoginInput = { school: string; username: string; password: string; totp?: string };

/** Kirish xatolari: UI tegishli xabarni tanlaydi. */
export type LoginErrorCode = 'INVALID_CREDENTIALS' | 'LOCKED' | 'TOTP_REQUIRED' | 'TOTP_INVALID' | 'NETWORK';

export class LoginError extends Error {
  constructor(
    readonly code: LoginErrorCode,
    readonly retryAfterSeconds?: number,
  ) {
    super(code);
    this.name = 'LoginError';
  }
}

const LAST_SCHOOL_KEY = 'parvoz-school:last-school';
let me: HttpMe | null = null;
const listeners = new Set<() => void>();

export function currentMe(): HttpMe | null {
  return me;
}

export function subscribeMe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function lastSchoolCode(): string {
  try {
    return localStorage.getItem(LAST_SCHOOL_KEY) ?? '';
  } catch {
    return '';
  }
}

/** Kirish sahifasidagi maktab kodi: URL'dan (`?school=`) yoki oxirgi kirishdan. */
export function initialSchoolCode(): string {
  const fromUrl = new URLSearchParams(window.location.search).get('school');
  return (fromUrl ?? lastSchoolCode()).trim().toLowerCase();
}

function apply(payload: { accessToken: string; me: HttpMe }): Session {
  setAccessToken(payload.accessToken);
  me = payload.me;
  const session: Session = {
    staffId: payload.me.staff.id,
    username: payload.me.staff.username ?? payload.me.staff.fullName,
    role: payload.me.staff.role,
    loggedInAt: new Date().toISOString(),
  };
  setSession(session);
  for (const l of listeners) l();
  return session;
}

function clear(): void {
  setAccessToken(null);
  me = null;
  setSession(null);
  for (const l of listeners) l();
}

async function post(path: string, body?: unknown): Promise<Response> {
  return fetch(`${API_BASE}${path}`, {
    method: 'POST',
    credentials: 'include',
    headers: { Accept: 'application/json', ...(body !== undefined && { 'Content-Type': 'application/json' }) },
    ...(body !== undefined && { body: JSON.stringify(body) }),
  });
}

export async function httpSignIn(input: LoginInput): Promise<Session> {
  let res: Response;
  try {
    res = await post('/school/auth/login', input);
  } catch {
    throw new LoginError('NETWORK');
  }
  const body = (await res.json().catch(() => ({}))) as { code?: string; retryAfterSeconds?: number; accessToken?: string; me?: HttpMe };
  if (!res.ok || !body.accessToken || !body.me) {
    const code = (['LOCKED', 'TOTP_REQUIRED', 'TOTP_INVALID'] as const).find((c) => c === body.code) ?? 'INVALID_CREDENTIALS';
    throw new LoginError(code, body.retryAfterSeconds);
  }
  try {
    localStorage.setItem(LAST_SCHOOL_KEY, input.school.trim().toLowerCase());
  } catch {
    // bloklangan xotira — kod eslab qolinmaydi
  }
  return apply({ accessToken: body.accessToken, me: body.me });
}

let restoring: Promise<boolean> | null = null;

/**
 * Cookie orqali sessiyani tiklash (sahifa ochilganda, 401 dan keyin).
 * Bir vaqtdagi chaqiruvlar bitta refresh so'rovini bo'lishadi.
 */
export function restoreHttpSession(): Promise<boolean> {
  restoring ??= refreshSession().finally(() => {
    restoring = null;
  });
  return restoring;
}

async function refreshSession(): Promise<boolean> {
  try {
    const res = await post('/school/auth/refresh');
    if (!res.ok) {
      clear();
      return false;
    }
    apply((await res.json()) as { accessToken: string; me: HttpMe });
    return true;
  } catch {
    return false;
  }
}

export async function httpSignOut(): Promise<void> {
  try {
    await post('/school/auth/logout');
  } finally {
    clear();
  }
}

setRefreshHandler(restoreHttpSession);
setSessionLostHandler(clear);

export { ServiceError };
