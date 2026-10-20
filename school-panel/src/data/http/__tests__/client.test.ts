import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ServiceError } from '@/data/contracts';
import { http, setAccessToken, setRefreshHandler, setSessionLostHandler, toServiceError } from '../client';

type Call = { url: string; init: RequestInit };

function mockFetch(responses: Array<{ status: number; body?: unknown }>) {
  const calls: Call[] = [];
  const queue = [...responses];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      const next = queue.shift() ?? { status: 500 };
      return new Response(next.body === undefined ? null : JSON.stringify(next.body), { status: next.status });
    }),
  );
  return calls;
}

describe('http client', () => {
  beforeEach(() => {
    setAccessToken('t1');
    setRefreshHandler(async () => false);
    setSessionLostHandler(null);
  });
  afterEach(() => vi.unstubAllGlobals());

  it('Bearer token, JSON tanasi va so\'rov parametrlari', async () => {
    const calls = mockFetch([{ status: 200, body: { ok: true } }]);
    const res = await http<{ ok: boolean }>('POST', '/school/classes', { body: { grade: 7 }, query: { search: 'a b', empty: '', none: undefined } });
    expect(res).toEqual({ ok: true });
    expect(calls[0].url).toBe('/api/school/classes?search=a+b');
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe('Bearer t1');
    expect(calls[0].init.body).toBe('{"grade":7}');
    expect(calls[0].init.credentials).toBe('include');
  });

  it('204 — undefined', async () => {
    mockFetch([{ status: 204 }]);
    await expect(http('DELETE', '/school/holidays/x')).resolves.toBeUndefined();
  });

  it('401 → bitta refresh, so\'rov takrorlanadi', async () => {
    const calls = mockFetch([{ status: 401 }, { status: 200, body: [1] }]);
    const refresh = vi.fn(async () => {
      setAccessToken('t2');
      return true;
    });
    setRefreshHandler(refresh);
    await expect(http('GET', '/school/staff')).resolves.toEqual([1]);
    expect(refresh).toHaveBeenCalledTimes(1);
    expect((calls[1].init.headers as Record<string, string>).Authorization).toBe('Bearer t2');
  });

  it('refresh ham ishlamasa — sessiya yo\'qoladi va xato', async () => {
    mockFetch([{ status: 401, body: { code: 'UNAUTHORIZED' } }]);
    const lost = vi.fn();
    setSessionLostHandler(lost);
    await expect(http('GET', '/school/staff')).rejects.toBeInstanceOf(ServiceError);
    expect(lost).toHaveBeenCalled();
  });

  it('parallel 401 lar — bitta refresh', async () => {
    mockFetch([{ status: 401 }, { status: 401 }, { status: 200, body: 'a' }, { status: 200, body: 'b' }]);
    let resolve!: (v: boolean) => void;
    const refresh = vi.fn(() => new Promise<boolean>((r) => (resolve = r)));
    setRefreshHandler(refresh);
    const both = Promise.all([http('GET', '/a'), http('GET', '/b')]);
    await vi.waitFor(() => expect(refresh).toHaveBeenCalledTimes(1));
    resolve(true);
    await expect(both).resolves.toEqual(['a', 'b']);
  });

  it('xato kodlari panel ServiceError ga', () => {
    expect(toServiceError(400, { code: 'VALIDATION', message: 'name: errors.form.required' })).toMatchObject({
      code: 'VALIDATION',
      message: 'name: errors.form.required',
    });
    expect(toServiceError(409, { message: 'x' }).code).toBe('CONFLICT');
    expect(toServiceError(403, {}).code).toBe('FORBIDDEN');
    expect(toServiceError(404, null).code).toBe('NOT_FOUND');
    expect(toServiceError(500, { message: ['a', 'b'] })).toMatchObject({ code: 'UNKNOWN', message: 'a; b' });
  });

  it('tarmoq xatosi — UNKNOWN', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => Promise.reject(new TypeError('offline'))));
    await expect(http('GET', '/x')).rejects.toMatchObject({ code: 'UNKNOWN', message: 'network' });
  });
});
