// Admin → Maktablar haqiqiy Postgres'da: ruxsat, yangi maktab + direktor
// (vaqtinchalik parol bir marta, panelga shu bilan kiriladi va almashtirish
// talab qilinadi), takroriy kod, psixolog hisobi, parolni tiklash (sessiyalar
// yopiladi, 2FA ixtiyoriy), direktor boshqaradigan xodimga tegilmaydi va
// audit yozuvlarida parol yo'q.

import { createModerator, TestModerator } from './factories';
import { resetDb } from './db';
import { createStaff, login } from './school-fixtures';
import { createTestApp, TestApp } from './test-app';

type Method = 'GET' | 'POST';

interface Credentials {
  schoolCode: string;
  username: string;
  temporaryPassword: string;
  account: { id: string; role: string; mustChangePassword: boolean; username: string | null };
}

const AUDIT_WAIT_MS = 2000;
const AUDIT_POLL_MS = 50;

const newSchool = (patch: object = {}) => ({
  code: 'parvoz-14',
  name: '14-maktab',
  city: 'Toshkent',
  director: { fullName: 'Karimov Akmal' },
  ...patch,
});

describe('Admin Schools API', () => {
  let t: TestApp;
  let admin: TestModerator;

  const api = (method: Method, url: string, payload?: object, token = admin.token) =>
    t.app.inject({
      method,
      url: `/api/admin/schools${url}`,
      headers: { authorization: `Bearer ${token}` },
      ...(payload && { payload }),
    });

  const createSchool = async (patch: object = {}) => {
    const res = await api('POST', '', newSchool(patch));
    expect(res.statusCode).toBe(201);
    return res.json() as { school: { id: string; code: string; accounts: Array<{ id: string }> }; credentials: Credentials };
  };

  const panelLogin = (school: string, username: string, password: string) =>
    t.app.inject({ method: 'POST', url: '/api/school/auth/login', payload: { school, username, password } });

  const auditRows = async (action: string, resourceId: string) => {
    const deadline = Date.now() + AUDIT_WAIT_MS;
    for (;;) {
      const rows = await t.prisma.moderatorAuditLog.findMany({ where: { action, resourceId } });
      if (rows.length > 0 || Date.now() > deadline) return rows;
      await new Promise((resolve) => setTimeout(resolve, AUDIT_POLL_MS));
    }
  };

  beforeAll(async () => {
    t = await createTestApp();
  });

  beforeEach(async () => {
    await resetDb(t.prisma);
    admin = await createModerator(t.prisma, ['manage_schools']);
  });

  afterAll(() => t.close());

  it('manage_schools ruxsatisiz — 403, tokensiz — 401', async () => {
    const other = await createModerator(t.prisma, ['manage_learning']);
    expect((await api('GET', '', undefined, other.token)).statusCode).toBe(403);
    expect((await api('POST', '', newSchool(), other.token)).statusCode).toBe(403);
    const anonymous = await t.app.inject({ method: 'GET', url: '/api/admin/schools' });
    expect(anonymous.statusCode).toBe(401);
    expect(await t.prisma.school.count()).toBe(0);
  });

  it('yangi maktab: direktor vaqtinchalik parol bilan panelga kiradi va parolni almashtirishi so\'raladi', async () => {
    const res = await api('POST', '', newSchool({ code: ' Parvoz-14 ', director: { fullName: 'Karimov Akmal', username: 'Akmal' } }));
    expect(res.statusCode).toBe(201);
    expect(res.headers['cache-control']).toBe('no-store');
    const { school, credentials } = res.json() as { school: Record<string, unknown>; credentials: Credentials };

    expect(school).toMatchObject({
      code: 'parvoz-14',
      name: '14-maktab',
      shortName: '14-maktab',
      city: 'Toshkent',
      status: 'ACTIVE',
      counts: { classes: 0, students: 0, staff: 1, linkedGuardians: 0 },
    });
    expect(credentials).toMatchObject({
      schoolCode: 'parvoz-14',
      username: 'akmal',
      account: { role: 'DIRECTOR', mustChangePassword: true, username: 'akmal' },
    });
    expect(credentials.temporaryPassword).toMatch(/^[A-Za-z2-9]{12}$/);
    // Javobda maxfiy maydonlar yo'q.
    expect(res.body).not.toMatch(/passwordHash|kioskSecret|totpSecret/);

    const shifts = await t.prisma.schoolShift.findMany({ where: { schoolId: school.id as string } });
    expect(shifts).toHaveLength(1);
    expect(shifts[0]).toMatchObject({ start: '08:00', end: '13:25' });

    const loggedIn = await panelLogin('parvoz-14', 'akmal', credentials.temporaryPassword);
    expect(loggedIn.statusCode).toBe(200);
    expect(loggedIn.json().me.mustChangePassword).toBe(true);
    const blocked = await t.app.inject({
      method: 'GET',
      url: '/api/school/classes',
      headers: { authorization: `Bearer ${loggedIn.json().accessToken}` },
    });
    expect(blocked.statusCode).toBe(403);
    expect(blocked.json().code).toBe('PASSWORD_CHANGE_REQUIRED');

    // Ikki jurnal: admin audit (parolsiz) va maktab jurnali ("Parvoz admin").
    const [adminRow] = await auditRows('school.create', school.id as string);
    expect(adminRow).toMatchObject({ moderatorId: admin.id, resourceType: 'school' });
    expect(JSON.stringify(adminRow.details)).not.toContain(credentials.temporaryPassword);
    const created = await t.prisma.schoolAuditLog.findMany({ where: { schoolId: school.id as string, action: 'school.create' } });
    expect(created).toEqual([expect.objectContaining({ actorName: 'Parvoz admin', actorId: null, module: 'SCHOOL' })]);
  });

  it('takroriy yoki noto\'g\'ri kod — 409 / 400, maktab yaratilmaydi', async () => {
    await createSchool();
    const dup = await api('POST', '', newSchool({ code: 'PARVOZ-14', name: 'Boshqa' }));
    expect(dup.statusCode).toBe(409);
    expect(dup.json().code).toBe('SCHOOL_CODE_TAKEN');

    const bad = await api('POST', '', newSchool({ code: '14 maktab' }));
    expect(bad.statusCode).toBe(400);
    expect(bad.json()).toMatchObject({ code: 'VALIDATION', message: expect.stringMatching(/^code: /) });

    const noDirector = await api('POST', '', newSchool({ code: 'parvoz-15', director: { fullName: '' } }));
    expect(noDirector.statusCode).toBe(400);
    expect(await t.prisma.school.count()).toBe(1);
  });

  it('ro\'yxat: yangisi oldin, qidiruv (nom, kod, shahar) va sahifalash', async () => {
    await createSchool({ code: 'parvoz-14', name: '14-maktab', city: 'Toshkent' });
    await createSchool({ code: 'parvoz-qa', name: 'Parvoz QA maktabi', city: 'Samarqand' });

    const all = (await api('GET', '?limit=1')).json();
    expect(all.pagination).toEqual({ page: 1, limit: 1, total: 2, totalPages: 2 });
    expect(all.items[0]).toMatchObject({ code: 'parvoz-qa', accounts: [expect.objectContaining({ role: 'DIRECTOR' })] });

    for (const q of ['samar', 'QA', 'parvoz-q']) {
      const found = (await api('GET', `?q=${encodeURIComponent(q)}`)).json();
      expect(found.items.map((s: { code: string }) => s.code)).toEqual(['parvoz-qa']);
    }
  });

  it('psixolog hisobi: panelga kiradi; band login — 409; o\'qituvchi — 400', async () => {
    const { school } = await createSchool();
    const res = await api('POST', `/${school.id}/staff`, { role: 'PSYCHOLOGIST', fullName: 'Yusupova Malika', username: 'psixolog' });
    expect(res.statusCode).toBe(201);
    const psych = res.json() as Credentials;
    expect(psych.account).toMatchObject({ role: 'PSYCHOLOGIST', username: 'psixolog' });
    expect((await panelLogin('parvoz-14', 'psixolog', psych.temporaryPassword)).statusCode).toBe(200);
    const saved = await t.prisma.schoolStaff.findUniqueOrThrow({ where: { id: psych.account.id } });
    expect(saved.position).toBe('Psixolog');

    const taken = await api('POST', `/${school.id}/staff`, { role: 'DIRECTOR', fullName: 'Boshqa', username: 'psixolog' });
    expect(taken.statusCode).toBe(409);
    expect(taken.json().code).toBe('USERNAME_TAKEN');

    const teacher = await api('POST', `/${school.id}/staff`, { role: 'TEACHER', fullName: 'Aliyev Vali', username: 'vali' });
    expect(teacher.statusCode).toBe(400);

    const detail = (await api('GET', `/${school.id}`)).json();
    expect(detail.accounts.map((a: { role: string }) => a.role)).toEqual(['DIRECTOR', 'PSYCHOLOGIST']);
  });

  it('parolni tiklash: eski parol va sessiya ishlamaydi, blok ochiladi, 2FA ixtiyoriy o\'chadi', async () => {
    const { school, credentials } = await createSchool();
    const directorId = credentials.account.id;
    const before = await panelLogin('parvoz-14', 'direktor', credentials.temporaryPassword);
    const refreshCookie = before.cookies.find((c) => c.name === 'parvoz_school_rt');
    await t.prisma.schoolStaff.update({
      where: { id: directorId },
      data: { failedLogins: 9, lockedUntil: new Date(Date.now() + 60_000), totpEnabled: true, totpSecret: 'secret' },
    });

    const res = await api('POST', `/${school.id}/staff/${directorId}/reset-password`, { resetTotp: true });
    expect(res.statusCode).toBe(200);
    expect(res.headers['cache-control']).toBe('no-store');
    const next = res.json() as Credentials;
    expect(next.temporaryPassword).not.toBe(credentials.temporaryPassword);

    const saved = await t.prisma.schoolStaff.findUniqueOrThrow({ where: { id: directorId } });
    expect(saved).toMatchObject({ failedLogins: 0, lockedUntil: null, totpEnabled: false, totpSecret: null, mustChangePassword: true });
    expect((await panelLogin('parvoz-14', 'direktor', credentials.temporaryPassword)).statusCode).toBe(401);
    expect((await panelLogin('parvoz-14', 'direktor', next.temporaryPassword)).statusCode).toBe(200);
    const refreshed = await t.app.inject({
      method: 'POST',
      url: '/api/school/auth/refresh',
      headers: { cookie: `parvoz_school_rt=${refreshCookie?.value}` },
    });
    expect(refreshed.statusCode).toBe(401);

    const [adminRow] = await auditRows('school.staff.resetPassword', directorId);
    expect(adminRow.details).toMatchObject({ school: 'parvoz-14', role: 'DIRECTOR', resetTotp: true });
    expect(JSON.stringify(adminRow.details)).not.toContain(next.temporaryPassword);
  });

  it('login o\'chirilgan psixolog: yangi login bilan tiklanadi; loginsiz — 409', async () => {
    const { school } = await createSchool();
    const psych = await t.prisma.schoolStaff.create({
      data: { schoolId: school.id, fullName: 'Yusupova Malika', role: 'PSYCHOLOGIST' },
    });
    const missing = await api('POST', `/${school.id}/staff/${psych.id}/reset-password`, {});
    expect(missing.statusCode).toBe(409);
    expect(missing.json().code).toBe('USERNAME_REQUIRED');

    const res = await api('POST', `/${school.id}/staff/${psych.id}/reset-password`, { username: 'psixolog' });
    expect(res.statusCode).toBe(200);
    const creds = res.json() as Credentials;
    expect(creds.username).toBe('psixolog');
    expect((await panelLogin('parvoz-14', 'psixolog', creds.temporaryPassword)).statusCode).toBe(200);
  });

  it('direktor boshqaradigan xodim (o\'qituvchi) va boshqa maktab xodimi — tegilmaydi', async () => {
    const { school } = await createSchool();
    const other = await createSchool({ code: 'parvoz-15', name: '15-maktab' });
    const teacher = await createStaff(t.prisma, school.id, 'TEACHER', 'oqituvchi');
    const managed = await api('POST', `/${school.id}/staff/${teacher.id}/reset-password`, {});
    expect(managed.statusCode).toBe(409);
    expect(managed.json().code).toBe('MANAGED_BY_SCHOOL');

    const foreign = await api('POST', `/${school.id}/staff/${other.credentials.account.id}/reset-password`, {});
    expect(foreign.statusCode).toBe(404);
    expect((await api('GET', '/00000000-0000-4000-8000-000000000000')).statusCode).toBe(404);
    expect((await api('GET', '/not-a-uuid')).statusCode).toBe(400);
    await expect(login(t.app, 'oqituvchi', 'parvoz-14')).resolves.toBeTruthy();
  });
});
