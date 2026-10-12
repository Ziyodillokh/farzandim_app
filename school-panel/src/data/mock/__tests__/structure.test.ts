import { beforeEach, describe, expect, it } from 'vitest';

import { PERMISSIONS } from '@/auth/permissions';
import { auditShape, diffValues } from '@/features/audit/diff';
import { getTables } from '../db';
import { classesService } from '../services/classes';
import { demoService } from '../services/demo';
import { schoolService } from '../services/school';
import { auditService, staffService } from '../services/staff';
import { guardiansService } from '../services/students';
import { freshDb, loginAs } from './helpers';

const lastAudit = () => getTables().audit.at(-1);

describe('sinflar', () => {
  beforeEach(freshDb);

  it('sinf rahbari faqat o\'z sinfini ko\'radi, boshqasiga kira olmaydi', async () => {
    loginAs('HOMEROOM');
    const rows = await classesService.list();
    expect(rows.map((r) => r.id)).toEqual(['cls-7a']);
    await expect(classesService.detail('cls-8b')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    await expect(classesService.modeNow('cls-8b')).rejects.toMatchObject({ code: 'FORBIDDEN' });
    expect(Object.keys(await classesService.modesNow())).toEqual(['cls-7a']);
  });

  it('psixolog va navbatchi sinflar ro\'yxatini ko\'rmaydi', async () => {
    loginAs('PSYCHOLOGIST');
    await expect(classesService.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('DUTY');
    await expect(classesService.detail('cls-7a')).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('detail: sinf rahbari kontakti va smena', async () => {
    loginAs('ADMIN');
    const d = await classesService.detail('cls-7a');
    expect(d.name).toBe('7-A');
    expect(d.homeroom?.id).toBe('stf-homeroom-7a');
    expect(d.homeroom?.phone).toMatch(/^\+998/);
    expect(d.shift?.id).toBe('shf-1');
    expect(d.size).toBeGreaterThan(0);
    await expect(classesService.detail('cls-nope')).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });

  it('modeNow: dushanba 10:00 — 1-smena darsda (cheklov), 2-smena hali boshlanmagan', async () => {
    loginAs('DIRECTOR');
    const senior = await classesService.modeNow('cls-7a');
    expect(senior.date).toBe('2026-10-12');
    expect(senior.state.kind).toBe('LESSON');
    expect(senior.state.restricted).toBe(true);
    const junior = await classesService.modeNow('cls-1a');
    expect(junior.state).toMatchObject({ kind: 'BEFORE', startsAt: '13:30' });
  });

  it('yaratish: audit, takroriy nom CONFLICT, noto\'g\'ri smena VALIDATION', async () => {
    loginAs('ADMIN');
    const before = getTables().audit.length;
    const cls = await classesService.create({ grade: 5, letter: 'v', shiftId: 'shf-1', homeroomStaffId: null, room: '205v' });
    expect(cls.name).toBe('5-V');
    expect(getTables().audit.length).toBe(before + 1);
    expect(lastAudit()?.action).toBe('class.create');
    await expect(classesService.create({ grade: 5, letter: 'V', shiftId: 'shf-1' })).rejects.toMatchObject({ code: 'CONFLICT' });
    await expect(classesService.create({ grade: 5, letter: 'G', shiftId: 'shf-x' })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(classesService.create({ grade: 12, letter: 'A', shiftId: 'shf-1' })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(classesService.create({ grade: 5, letter: 'D', shiftId: 'shf-1', homeroomStaffId: 'stf-director' })).rejects.toMatchObject({
      code: 'VALIDATION',
    });
  });

  it('sinf rahbari ko\'rish mumkin, lekin sinf yarata olmaydi', async () => {
    loginAs('HOMEROOM');
    await expect(classesService.create({ grade: 5, letter: 'V', shiftId: 'shf-1' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });

  it('sinf rahbarini almashtirish xodimlar jadvalini ham yangilaydi', async () => {
    loginAs('ADMIN');
    await classesService.update('cls-8b', { grade: 8, letter: 'B', shiftId: 'shf-1', homeroomStaffId: 'stf-hr-9a', room: '208b' });
    const t = getTables();
    expect(t.classes.find((c) => c.id === 'cls-8b')?.homeroomStaffId).toBe('stf-hr-9a');
    expect(t.staff.find((s) => s.id === 'stf-hr-9a')?.classIds).toEqual(expect.arrayContaining(['cls-9a', 'cls-8b']));
    expect(t.staff.find((s) => s.id === 'stf-hr-8b')?.classIds).not.toContain('cls-8b');
    expect(lastAudit()).toMatchObject({ action: 'class.update', entityId: 'cls-8b' });
  });

  it('o\'quvchisi bor sinf o\'chirilmaydi, bo\'sh sinf o\'chiriladi', async () => {
    loginAs('ADMIN');
    await expect(classesService.remove('cls-7a')).rejects.toMatchObject({ code: 'CONFLICT' });
    const cls = await classesService.create({ grade: 6, letter: 'V', shiftId: 'shf-1' });
    await classesService.remove(cls.id);
    expect(getTables().classes.some((c) => c.id === cls.id)).toBe(false);
    expect(lastAudit()?.action).toBe('class.delete');
  });
});

describe('ommaviy taklif (ota-onalar)', () => {
  beforeEach(freshDb);

  it('sinf bo\'yicha: barcha taklif qilinmaganlarga kod beriladi, bitta audit yozuvi', async () => {
    loginAs('ADMIN');
    const pending = await guardiansService.list({ classId: 'cls-5a', linkStatus: 'NOT_INVITED', limit: 500 });
    expect(pending.pagination.total).toBeGreaterThan(0);
    const auditBefore = getTables().audit.length;
    const res = await classesService.inviteGuardians({ classId: 'cls-5a' });
    expect(res.invited).toBe(pending.pagination.total);
    expect(getTables().audit.length).toBe(auditBefore + 1);
    expect(lastAudit()).toMatchObject({ module: 'GUARDIANS', action: 'guardian.inviteBulk', entityId: 'cls-5a' });
    const ids = new Set(pending.items.map((g) => g.id));
    const invited = getTables().guardians.filter((g) => ids.has(g.id));
    expect(invited.every((g) => g.linkStatus === 'INVITED' && /^[A-Z2-9]{6}$/.test(g.inviteCode ?? ''))).toBe(true);
    expect(new Set(invited.map((g) => g.inviteCode)).size).toBe(invited.length);
    const again = await classesService.inviteGuardians({ classId: 'cls-5a' });
    expect(again.invited).toBe(0);
    expect(getTables().audit.length).toBe(auditBefore + 1);
  });

  it('sinf rahbari faqat o\'z sinfi ota-onalarini taklif qiladi', async () => {
    loginAs('HOMEROOM');
    await expect(classesService.inviteGuardians({ classId: 'cls-8b' })).rejects.toMatchObject({ code: 'FORBIDDEN' });
    const otherBefore = getTables().guardians.filter((g) => g.linkStatus === 'NOT_INVITED').length;
    const res = await classesService.inviteGuardians();
    expect(getTables().guardians.filter((g) => g.linkStatus === 'NOT_INVITED').length).toBe(otherBefore - res.invited);
    const own = await guardiansService.list({ linkStatus: 'NOT_INVITED', limit: 500 });
    expect(own.pagination.total).toBe(0);
  });

  it('navbatchi taklif yubora olmaydi; qidiruv uzunligi tekshiriladi', async () => {
    loginAs('DUTY');
    await expect(classesService.inviteGuardians()).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('ADMIN');
    await expect(classesService.inviteGuardians({ search: 'x'.repeat(200) })).rejects.toMatchObject({ code: 'VALIDATION' });
  });
});

describe('xodimlar', () => {
  beforeEach(freshDb);

  it('faqat direktor xodim qo\'shadi; sinf rahbari sinfsiz bo\'lmaydi', async () => {
    loginAs('ADMIN');
    const input = { fullName: 'Test Xodim', position: 'O\'qituvchi', role: 'HOMEROOM' as const, phone: '+998901234567', classIds: ['cls-6b'] };
    await expect(staffService.create(input)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('DIRECTOR');
    await expect(staffService.create({ ...input, classIds: [] })).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(staffService.create({ ...input, classIds: ['cls-nope'] })).rejects.toMatchObject({ code: 'VALIDATION' });
    const created = await staffService.create(input);
    const t = getTables();
    expect(created.phone).toBe('+998 90 123 45 67');
    expect(t.classes.find((c) => c.id === 'cls-6b')?.homeroomStaffId).toBe(created.id);
    expect(t.staff.find((s) => s.id === 'stf-hr-6b')?.classIds).toEqual([]);
    expect(lastAudit()).toMatchObject({ action: 'staff.create', entityId: created.id });
  });

  it('sinfga bog\'lanmagan rollarda sinflar tozalanadi', async () => {
    loginAs('DIRECTOR');
    const created = await staffService.create({ fullName: 'Navbatchi Ikki', position: 'Navbatchi', role: 'DUTY', phone: '+998 91 000 00 00', classIds: ['cls-7a'] });
    expect(created.classIds).toEqual([]);
  });

  it('rol o\'zgarsa sinf rahbarligi bo\'shaydi; demo hisob roli qulflangan', async () => {
    loginAs('DIRECTOR');
    const hr = getTables().staff.find((s) => s.id === 'stf-hr-9b');
    expect(hr).toBeDefined();
    await staffService.update('stf-hr-9b', { ...hr!, role: 'TEACHER' });
    expect(getTables().classes.find((c) => c.id === 'cls-9b')?.homeroomStaffId).toBeNull();
    const demo = getTables().staff.find((s) => s.id === 'stf-homeroom-7a');
    await expect(staffService.update('stf-homeroom-7a', { ...demo!, role: 'TEACHER' })).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('faollik: o\'zini va demo hisobni o\'chirib bo\'lmaydi, audit oldin/keyin bilan', async () => {
    loginAs('DIRECTOR');
    await expect(staffService.setActive('stf-director', false)).rejects.toMatchObject({ code: 'CONFLICT' });
    await expect(staffService.setActive('stf-admin', false)).rejects.toMatchObject({ code: 'CONFLICT' });
    const res = await staffService.setActive('stf-t-1', false);
    expect(res.active).toBe(false);
    expect(lastAudit()).toMatchObject({ action: 'staff.deactivate', before: { active: true }, after: { active: false } });
    const summary = await staffService.summary();
    expect(summary.inactive).toBe(1);
    expect(summary.demo).toBe(5);
    expect(summary.byRole.DIRECTOR).toBe(1);
  });

  it('rollar matritsasi — har rol ma\'lum ruxsatlardan iborat', async () => {
    loginAs('ADMIN');
    const roles = await staffService.roles();
    expect(roles).toHaveLength(6);
    for (const r of roles) for (const p of r.permissions) expect(PERMISSIONS).toContain(p);
    loginAs('HOMEROOM');
    await expect(staffService.roles()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('audit jurnali', () => {
  beforeEach(freshDb);

  it('modul, xodim va sana bo\'yicha filtr; eksport hammasini qaytaradi', async () => {
    loginAs('DIRECTOR');
    await classesService.create({ grade: 4, letter: 'V', shiftId: 'shf-2' });
    const byModule = await auditService.list({ module: 'CLASSES' });
    expect(byModule.items.every((a) => a.module === 'CLASSES')).toBe(true);
    expect(byModule.items[0]?.action).toBe('class.create');
    const byActor = await auditService.list({ actorId: 'stf-homeroom-7a', limit: 100 });
    expect(byActor.items.length).toBeGreaterThan(0);
    expect(byActor.items.every((a) => a.actorId === 'stf-homeroom-7a')).toBe(true);
    const future = await auditService.list({ from: '2999-01-01' });
    expect(future.pagination.total).toBe(0);
    const all = await auditService.exportRows({});
    expect(all.length).toBe(getTables().audit.length);
    expect((await auditService.actors()).length).toBeGreaterThan(1);
  });

  it('sinf rahbari audit jurnalini ko\'rmaydi', async () => {
    loginAs('HOMEROOM');
    await expect(auditService.list()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});

describe('sozlamalar', () => {
  beforeEach(freshDb);

  it('profil: faqat direktor, audit oldin/keyin bilan', async () => {
    const profile = { name: 'Yangi maktab', shortName: 'YM', city: 'Samarqand', address: '', phone: '', academicYear: '2026–2027', lateAfterMinutes: 15 };
    loginAs('ADMIN');
    await expect(schoolService.updateProfile(profile)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('DIRECTOR');
    const school = await schoolService.updateProfile(profile);
    expect(school).toMatchObject({ name: 'Yangi maktab', city: 'Samarqand', lateAfterMinutes: 15 });
    expect(lastAudit()).toMatchObject({ action: 'school.update', before: { name: 'Parvoz namunaviy maktabi' } });
    await expect(schoolService.updateProfile({ ...profile, lateAfterMinutes: 99 })).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('logo: faqat rasm data URL qabul qilinadi', async () => {
    loginAs('DIRECTOR');
    await expect(schoolService.setLogo('https://evil.example/logo.png')).rejects.toMatchObject({ code: 'VALIDATION' });
    const school = await schoolService.setLogo('data:image/png;base64,iVBORw0KGgo=');
    expect(school.logo).toContain('data:image/png');
    expect((await schoolService.setLogo(null)).logo).toBeNull();
    expect(lastAudit()?.action).toBe('school.logoRemove');
  });

  it('demo tiklash: faqat direktor, maktab nomi saqlanadi', async () => {
    loginAs('ADMIN');
    expect(() => demoService.reset()).toThrow();
    loginAs('DIRECTOR');
    await schoolService.updateProfile({ name: 'Brend maktab', shortName: 'BM', city: 'Buxoro', academicYear: '2026–2027', lateAfterMinutes: 10 });
    await classesService.create({ grade: 3, letter: 'V', shiftId: 'shf-2' });
    demoService.reset();
    const t = getTables();
    expect(t.school.name).toBe('Brend maktab');
    expect(t.classes.some((c) => c.name === '3-V')).toBe(false);
  });
});

describe('audit farqi (oldin/keyin)', () => {
  it('o\'zgargan, qo\'shilgan va o\'zgarmagan maydonlarni ajratadi', () => {
    const rows = diffValues({ name: '7-A', room: '207', meta: { a: 1 } }, { name: '7-A', room: '208', meta: { a: 2 }, extra: true });
    const byField = Object.fromEntries(rows.map((r) => [r.field, r.kind]));
    expect(byField).toEqual({ name: 'same', room: 'changed', 'meta.a': 'changed', extra: 'added' });
  });

  it('yaratish/o\'chirish/tafsilotsiz yozuvni aniqlaydi', () => {
    expect(auditShape(null, { a: 1 })).toBe('create');
    expect(auditShape({ a: 1 }, null)).toBe('delete');
    expect(auditShape({ a: 1 }, { a: 2 })).toBe('update');
    expect(auditShape(null, null)).toBe('none');
    expect(diffValues({ a: 1 }, null)).toEqual([{ field: 'a', before: 1, after: undefined, kind: 'removed' }]);
    expect(diffValues(null, 'x')).toEqual([{ field: 'value', before: undefined, after: 'x', kind: 'added' }]);
  });

  it('haqiqiy servis yozuvi o\'qiladigan farq beradi', async () => {
    freshDb();
    loginAs('DIRECTOR');
    await staffService.setActive('stf-t-2', false);
    const entry = getTables().audit.at(-1);
    expect(diffValues(entry?.before, entry?.after)).toEqual([{ field: 'active', before: true, after: false, kind: 'changed' }]);
  });
});
