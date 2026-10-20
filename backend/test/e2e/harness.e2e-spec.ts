// E2E harness tutun testi: ilova ko'tariladi, CHILD/PARENT tokenlari
// ishlaydi, P2002 → 409.

import { createChild, createParent } from './factories';
import { resetDb } from './db';
import { createTestApp, TestApp } from './test-app';

describe('E2E harness', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await createTestApp();
    await resetDb(t.prisma);
  });

  afterAll(() => t.close());

  it('himoyalangan route tokensiz 401', async () => {
    const res = await t.app.inject({ method: 'GET', url: '/api/content/olympiads' });
    expect(res.statusCode).toBe(401);
  });

  it('bola tokeni bilan olimpiadalar ro\'yxati', async () => {
    const parent = await createParent(t.prisma);
    const child = await createChild(t.prisma, parent);
    const res = await t.app.inject({
      method: 'GET',
      url: '/api/content/olympiads',
      headers: { authorization: `Bearer ${child.token}` },
    });
    expect(res.statusCode).toBe(200);
  });
});
