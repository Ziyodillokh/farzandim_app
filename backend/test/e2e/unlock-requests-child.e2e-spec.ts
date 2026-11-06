// F04 · Qo'shimcha vaqt: bola o'z so'rovlarini ko'radi va javob kutayotganini bekor qiladi.

import { resetDb } from './db';
import { api, captureRealtime, familyOf } from './kirish-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('Unlock requests: bola tomoni (F04)', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
  });

  afterAll(() => t.close());

  const ask = (token: string) =>
    api(t, 'POST', '/unlock-requests', {
      token,
      payload: { kind: 'SCREEN_TIME', requestedMinutes: 10, reason: 'Uy vazifasi uchun' },
    });

  it('GET /unlock-requests/mine — faqat o\'zining so\'nggi so\'rovlari, yangisi birinchi', async () => {
    const { child } = await familyOf(t);
    const other = await familyOf(t, 'Jasur Karimov');
    expect((await ask(child.token)).statusCode).toBe(201);
    expect((await ask(other.child.token)).statusCode).toBe(201);

    const res = await api(t, 'GET', '/unlock-requests/mine', { token: child.token });
    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.count).toBe(1);
    expect(body.requests[0]).toMatchObject({
      childId: child.childId,
      kind: 'SCREEN_TIME',
      status: 'PENDING',
      requestedMinutes: 10,
      reason: 'Uy vazifasi uchun',
    });
  });

  it('cancel: PENDING → CANCELLED, ota-onaga xabar; takror — o\'sha javob', async () => {
    const { parent, child } = await familyOf(t);
    const events = captureRealtime(t);
    const created = (await ask(child.token)).json();

    const res = await api(t, 'POST', `/unlock-requests/${created.id}/cancel`, { token: child.token });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toMatchObject({ id: created.id, status: 'CANCELLED' });
    expect(events.of(parent.userId, 'unlock_request:cancelled')).toHaveLength(1);

    const again = await api(t, 'POST', `/unlock-requests/${created.id}/cancel`, { token: child.token });
    expect(again.statusCode).toBe(200);
    expect(again.json().status).toBe('CANCELLED');

    // Bekor qilingan so'rovga ota-ona endi qaror bera olmaydi.
    const decide = await api(t, 'POST', `/unlock-requests/${created.id}/decide`, {
      token: parent.token,
      payload: { approve: true, grantedMinutes: 10 },
    });
    expect(decide.statusCode).toBeGreaterThanOrEqual(400);
  });

  it('cancel: qaror berilgan so\'rov — 409 ALREADY_DECIDED; boshqa bolaniki — 404', async () => {
    const { parent, child } = await familyOf(t);
    const other = await familyOf(t, 'Jasur Karimov');
    const created = (await ask(child.token)).json();
    await t.prisma.unlockRequest.update({
      where: { id: created.id },
      data: { status: 'DENIED', decidedAt: new Date() },
    });

    const res = await api(t, 'POST', `/unlock-requests/${created.id}/cancel`, { token: child.token });
    expect(res.statusCode).toBe(409);
    expect(res.json().code).toBe('ALREADY_DECIDED');

    const foreign = await api(t, 'POST', `/unlock-requests/${created.id}/cancel`, { token: other.child.token });
    expect(foreign.statusCode).toBe(404);

    // Ota-ona tokeni bilan — bola qurilmasi emas.
    const byParent = await api(t, 'POST', `/unlock-requests/${created.id}/cancel`, { token: parent.token });
    expect(byParent.statusCode).toBe(403);
  });
});
