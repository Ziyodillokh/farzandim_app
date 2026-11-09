// "To'laganman" so'rovi chek rasmi bilan (onlayn to'lov): multipart yuklash, EXIF tozalash,
// xodim paneli ro'yxatida imzolangan havola, proksi; naqd to'lov — rasmsiz (JSON, avvalgidek).

import { resetDb } from './db';
import { createParent, TestParent } from './factories';
import { addFamily, addPayment, createClass, Family, schoolCall } from './school-comms-fixtures';
import { heic, jpeg, memoryStorage, MemoryStorage, multipart } from './school-child-fixtures';
import { createSchool, createStaff, login, LoggedIn } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

describe('School payment receipt', () => {
  let t: TestApp;
  let storage: MemoryStorage;
  let call: ReturnType<typeof schoolCall>;
  let schoolId: string;
  let admin: LoggedIn;
  let mother: TestParent;
  let fam: Family;
  let paymentId: string;

  beforeAll(async () => {
    storage = memoryStorage();
    t = await createTestApp({ storage });
    call = schoolCall(t.app);
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    storage.objects.clear();
    schoolId = (await createSchool(t.prisma)).school.id;
    const cls = (await createClass(t.prisma, schoolId, 7, 'A')).id;
    await createStaff(t.prisma, schoolId, 'ADMIN', 'admin');
    admin = await login(t.app, 'admin');
    mother = await createParent(t.prisma);
    fam = await addFamily(t.prisma, schoolId, cls, { userId: mother.userId });
    paymentId = (await addPayment(t.prisma, schoolId, fam, '2099-04-05')).id;
  });

  afterAll(() => t.close());

  const upload = (files: Parameters<typeof multipart>[0], fields: Record<string, string>) => {
    const body = multipart(files, fields);
    return t.app.inject({
      method: 'POST',
      url: '/api/parent/school/verifications',
      headers: { authorization: `Bearer ${mother.token}`, ...body.headers },
      payload: body.payload,
    });
  };

  it('saves the receipt (EXIF stripped) and gives staff a signed proxy link', async () => {
    const res = await upload([{ data: jpeg('chek', 'GPS-SECRET'), field: 'receipt' }], {
      paymentReminderId: paymentId,
      message: "To'lov usuli: Click. Oy: Noyabr 2099.",
    });
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject({ status: 'OPEN', hasReceipt: true });

    const [key] = [...storage.objects.keys()];
    expect(key).toMatch(new RegExp(`/receipts/${schoolId}/${res.json().id}\\.jpg$`));
    expect(storage.objects.get(key!)!.body.toString('latin1')).not.toContain('GPS-SECRET');

    const list = (await call(admin, 'GET', '/comms/verifications')).json();
    const row = list.items[0];
    expect(row.receiptUrl).toMatch(/\/api\/school\/verifications\/receipts\/.+\?exp=\d+&sig=/);

    const path = new URL(row.receiptUrl).pathname + new URL(row.receiptUrl).search;
    const img = await t.app.inject({ method: 'GET', url: path });
    expect(img.statusCode).toBe(200);
    expect(img.headers['content-type']).toBe('image/jpeg');
    const forged = await t.app.inject({ method: 'GET', url: path.replace(/sig=[^&]+/, 'sig=AAAA') });
    expect(forged.statusCode).toBe(403);
  });

  it('keeps the JSON path for cash payments (no receipt)', async () => {
    const res = await t.app.inject({
      method: 'POST',
      url: '/api/parent/school/verifications',
      headers: { authorization: `Bearer ${mother.token}` },
      payload: { paymentReminderId: paymentId, message: "To'lov usuli: Naqd. Kotibiyatga berdim." },
    });
    expect(res.statusCode).toBe(201);
    expect(res.json().hasReceipt).toBe(false);
    expect((await call(admin, 'GET', '/comms/verifications')).json().items[0].receiptUrl).toBeNull();
    expect(storage.objects.size).toBe(0);
  });

  it('rejects unsupported images and removes the upload when the request conflicts', async () => {
    expect((await upload([{ data: heic(), field: 'receipt' }], { paymentReminderId: paymentId, message: 'Click' })).statusCode).toBe(415);

    const first = await upload([{ data: jpeg('a'), field: 'receipt' }], { paymentReminderId: paymentId, message: 'Click' });
    expect(first.statusCode).toBe(201);
    const second = await upload([{ data: jpeg('b'), field: 'receipt' }], { paymentReminderId: paymentId, message: 'Payme' });
    expect(second.statusCode).toBe(409);
    expect(storage.objects.size).toBe(1);
    expect(await t.prisma.schoolVerificationRequest.count()).toBe(1);
  });
});
