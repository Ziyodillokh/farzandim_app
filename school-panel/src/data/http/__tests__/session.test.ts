import { afterEach, describe, expect, it, vi } from 'vitest';

import { getSession, setSession } from '@/auth/session';
import { currentMe, httpSignIn, httpSignOut, LoginError, restoreHttpSession } from '../session';

const me = {
  staff: { id: 's1', fullName: 'Karimov Akmal', role: 'DIRECTOR', position: 'Direktor', phone: '', email: '', username: 'direktor', photo: null, portrait: null },
  school: { id: 'sc1', code: 'maktab-14', name: '14-maktab', shortName: '14', logo: null },
  scope: 'SCHOOL',
  classIds: [],
  permissions: ['dashboard.view'],
  mustChangePassword: false,
  totpEnabled: false,
};

function respond(status: number, body?: unknown) {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(body === undefined ? null : JSON.stringify(body), { status })));
}

describe('http session', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    setSession(null);
  });

  it('kirish — sessiya va me', async () => {
    respond(200, { accessToken: 'a', expiresIn: 900, me });
    const session = await httpSignIn({ school: 'Maktab-14', username: 'direktor', password: 'x' });
    expect(session).toMatchObject({ staffId: 's1', role: 'DIRECTOR', username: 'direktor' });
    expect(getSession()?.staffId).toBe('s1');
    expect(currentMe()?.school.code).toBe('maktab-14');
  });

  it.each([
    [{ code: 'LOCKED', retryAfterSeconds: 300 }, 'LOCKED'],
    [{ code: 'TOTP_REQUIRED' }, 'TOTP_REQUIRED'],
    [{ code: 'INVALID_CREDENTIALS' }, 'INVALID_CREDENTIALS'],
    [{}, 'INVALID_CREDENTIALS'],
  ])('kirish xatosi %j → %s', async (body, code) => {
    respond(401, body);
    await expect(httpSignIn({ school: 's', username: 'u', password: 'p' })).rejects.toMatchObject({ code });
  });

  it('tarmoq xatosi — NETWORK', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => Promise.reject(new TypeError('offline'))));
    await expect(httpSignIn({ school: 's', username: 'u', password: 'p' })).rejects.toBeInstanceOf(LoginError);
  });

  it('tiklash: cookie yaroqsiz — sessiya tozalanadi', async () => {
    setSession({ staffId: 'old', username: 'u', role: 'DUTY', loggedInAt: '' });
    respond(401, { code: 'SESSION_EXPIRED' });
    expect(await restoreHttpSession()).toBe(false);
    expect(getSession()).toBeNull();
  });

  it('tiklash: bir vaqtdagi chaqiruvlar bitta refresh so\'rovini bo\'lishadi', async () => {
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ accessToken: 'a', expiresIn: 900, me }), { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);
    const results = await Promise.all([restoreHttpSession(), restoreHttpSession(), restoreHttpSession()]);
    expect(results).toEqual([true, true, true]);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    // Tugagach keyingi tiklash — yangi so'rov.
    expect(await restoreHttpSession()).toBe(true);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('chiqish — server xato bersa ham sessiya tozalanadi', async () => {
    respond(200, { accessToken: 'a', expiresIn: 900, me });
    await httpSignIn({ school: 's', username: 'u', password: 'p' });
    respond(500);
    await httpSignOut().catch(() => undefined);
    expect(getSession()).toBeNull();
    expect(currentMe()).toBeNull();
  });
});
