import { describe, expect, it } from 'vitest';

import { internalRoute } from '../unsaved-changes';

const HERE = { href: 'https://farzandimedu.uz/school/timetable/' };

describe('internalRoute', () => {
  it('basePath olib tashlanadi, query va hash saqlanadi', () => {
    expect(internalRoute({ href: '/school/dashboard/' }, HERE, '/school')).toBe('/dashboard/');
    expect(internalRoute({ href: 'https://farzandimedu.uz/school/students/view/?id=stu-1#top' }, HERE, '/school')).toBe('/students/view/?id=stu-1#top');
    expect(internalRoute({ href: '/school/' }, HERE, '/school')).toBe('/');
  });

  it('basePath bo\'lmasa yo\'l o\'zgarmaydi', () => {
    expect(internalRoute({ href: '/dashboard/' }, { href: 'https://x.test/timetable/' }, '')).toBe('/dashboard/');
  });

  it('boshqa origin, _blank, yuklab olish va joriy sahifaning o\'zi — ushlanmaydi', () => {
    expect(internalRoute({ href: 'https://example.com/a' }, HERE, '/school')).toBeNull();
    expect(internalRoute({ href: '/school/kiosk/', target: '_blank' }, HERE, '/school')).toBeNull();
    expect(internalRoute({ href: '/school/file.csv', hasDownload: true }, HERE, '/school')).toBeNull();
    expect(internalRoute({ href: '/school/timetable/#grid' }, HERE, '/school')).toBeNull();
    expect(internalRoute({ href: '/school/timetable/' }, HERE, '/school')).toBeNull();
  });

  it('target="_self" ushlanadi', () => {
    expect(internalRoute({ href: '/school/classes/', target: '_self' }, HERE, '/school')).toBe('/classes/');
  });
});
