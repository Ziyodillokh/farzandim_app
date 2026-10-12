import { beforeEach, describe, expect, it } from 'vitest';

import { __setSessionForTests } from '@/auth/session';
import { getTables } from '../db';
import { profileService } from '../services/profile';
import { staffService } from '../services/staff';
import { freshDb, loginAs } from './helpers';

const PHOTO = `data:image/webp;base64,${'A'.repeat(400)}`;

describe('xodim rasmi', () => {
  beforeEach(freshDb);

  it('har kim o\'z rasmini yuklaydi; auditda rasm baytlari yo\'q', async () => {
    loginAs('HOMEROOM');
    await profileService.setPhoto('stf-homeroom-7a', PHOTO);
    expect((await profileService.me()).photo).toBe(PHOTO);
    expect(JSON.stringify(getTables().audit)).not.toContain('base64');
  });

  it('boshqaning rasmini faqat direktor (staff.manage) o\'zgartiradi', async () => {
    loginAs('ADMIN');
    await expect(profileService.setPhoto('stf-duty', PHOTO)).rejects.toMatchObject({ code: 'FORBIDDEN' });
    loginAs('DIRECTOR');
    await profileService.setPhoto('stf-duty', PHOTO);
    expect(getTables().staff.find((s) => s.id === 'stf-duty')?.photo).toBe(PHOTO);
  });

  it('noto\'g\'ri format va juda katta rasm rad etiladi', async () => {
    loginAs('DIRECTOR');
    await expect(profileService.setPhoto('stf-director', 'data:image/svg+xml;base64,PHN2Zz4=')).rejects.toMatchObject({ code: 'VALIDATION' });
    await expect(profileService.setPhoto('stf-director', `data:image/png;base64,${'A'.repeat(130_000)}`)).rejects.toMatchObject({ code: 'VALIDATION' });
  });

  it('xodim tahrirlanganda rasm va portret saqlanadi, audit snapshot\'ida rasm yo\'q', async () => {
    loginAs('DIRECTOR');
    await profileService.setPhoto('stf-admin', PHOTO);
    const admin = getTables().staff.find((s) => s.id === 'stf-admin');
    if (!admin) throw new Error('no admin');
    await staffService.update('stf-admin', { fullName: admin.fullName, position: 'Direktor o\'rinbosari', role: admin.role, phone: admin.phone, email: admin.email, classIds: admin.classIds });
    const after = getTables().staff.find((s) => s.id === 'stf-admin');
    expect(after?.photo).toBe(PHOTO);
    expect(after?.portrait).toBe('m-01');
    expect(JSON.stringify(getTables().audit)).not.toContain('base64');
  });

  it('login kartochkalari uchun demo profillar sessiyasiz', async () => {
    __setSessionForTests(null);
    const profiles = await profileService.demoProfiles();
    expect(Object.keys(profiles).sort()).toEqual(['stf-admin', 'stf-director', 'stf-duty', 'stf-homeroom-7a', 'stf-psychologist']);
    expect(profiles['stf-director']?.portrait).toBe('f-01');
    await expect(profileService.avatars()).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});
