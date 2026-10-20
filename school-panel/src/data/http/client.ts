import { ServiceError } from '@/data/contracts';
import { API_BASE } from '@/data/source';

/**
 * Backend HTTP mijozi: qisqa access token xotirada (localStorage'da EMAS),
 * refresh — httpOnly cookie. 401 da bir marta yangilanadi va so'rov
 * takrorlanadi; xatolar panel `ServiceError` kodlariga aylanadi.
 */

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
type Query = Record<string, string | number | boolean | null | undefined>;

let accessToken: string | null = null;
let refreshInFlight: Promise<boolean> | null = null;
let onSessionLost: (() => void) | null = null;
let refreshHandler: (() => Promise<boolean>) | null = null;

export function setAccessToken(token: string | null): void {
  accessToken = token;
}

/** Sessiya yo'qolganda (refresh ham ishlamadi) — chiqish. */
export function setSessionLostHandler(handler: (() => void) | null): void {
  onSessionLost = handler;
}

/** `http-session.ts` refresh funksiyasini ro'yxatdan o'tkazadi (aylanma import yo'q). */
export function setRefreshHandler(handler: () => Promise<boolean>): void {
  refreshHandler = handler;
}

const CODES = ['FORBIDDEN', 'NOT_FOUND', 'VALIDATION', 'CONFLICT'] as const;
type Code = (typeof CODES)[number] | 'UNKNOWN';

export function toServiceError(status: number, body: unknown): ServiceError {
  const b = (body && typeof body === 'object' ? body : {}) as { code?: unknown; message?: unknown };
  const fromBody = CODES.find((c) => c === b.code);
  const byStatus: Record<number, Code> = { 400: 'VALIDATION', 401: 'FORBIDDEN', 403: 'FORBIDDEN', 404: 'NOT_FOUND', 409: 'CONFLICT' };
  const code: Code = fromBody ?? byStatus[status] ?? 'UNKNOWN';
  const message = Array.isArray(b.message) ? b.message.join('; ') : typeof b.message === 'string' ? b.message : `HTTP ${status}`;
  return new ServiceError(code, message);
}

function buildUrl(path: string, query?: Query): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query ?? {})) {
    if (value !== undefined && value !== null && value !== '') params.set(key, String(value));
  }
  const qs = params.toString();
  return `${API_BASE}${path}${qs ? `?${qs}` : ''}`;
}

async function send(method: Method, path: string, body: unknown, query: Query | undefined): Promise<Response> {
  return fetch(buildUrl(path, query), {
    method,
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      ...(body !== undefined && { 'Content-Type': 'application/json' }),
      ...(accessToken && { Authorization: `Bearer ${accessToken}` }),
    },
    ...(body !== undefined && { body: JSON.stringify(body) }),
  });
}

/** Bitta parallel refresh (bir nechta 401 bir vaqtda kelsa ham). */
async function refreshOnce(): Promise<boolean> {
  if (!refreshHandler) return false;
  refreshInFlight ??= refreshHandler().finally(() => {
    refreshInFlight = null;
  });
  return refreshInFlight;
}

async function parse(res: Response): Promise<unknown> {
  if (res.status === 204) return undefined;
  const text = await res.text();
  if (!text) return undefined;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

export async function http<T>(method: Method, path: string, options: { body?: unknown; query?: Query } = {}): Promise<T> {
  let res: Response;
  try {
    res = await send(method, path, options.body, options.query);
    if (res.status === 401 && !path.startsWith('/school/auth/')) {
      if (await refreshOnce()) {
        res = await send(method, path, options.body, options.query);
      } else {
        onSessionLost?.();
      }
    }
  } catch {
    throw new ServiceError('UNKNOWN', 'network');
  }
  const data = await parse(res);
  if (!res.ok) throw toServiceError(res.status, data);
  return data as T;
}
