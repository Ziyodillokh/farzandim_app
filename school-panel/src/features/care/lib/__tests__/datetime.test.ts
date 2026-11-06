import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { toLocalInput } from '../datetime';

describe('toLocalInput', () => {
  const previous = process.env.TZ;
  beforeAll(() => {
    process.env.TZ = 'Asia/Tashkent';
  });
  afterAll(() => {
    if (previous === undefined) delete process.env.TZ;
    else process.env.TZ = previous;
  });

  it('zonasiz mahalliy vaqt (demo) kesiladi', () => {
    expect(toLocalInput('2026-10-14T12:30:00')).toBe('2026-10-14T12:30');
  });

  it('UTC ISO (backend) mahalliy vaqtga o\'giriladi — UTC soati mahalliy deb ko\'rsatilmaydi', () => {
    expect(toLocalInput('2026-11-06T07:30:00.000Z')).toBe('2026-11-06T12:30');
    expect(toLocalInput('2026-11-06T12:30:00+05:00')).toBe('2026-11-06T12:30');
  });

  it('bo\'sh qiymat — bo\'sh qator', () => {
    expect(toLocalInput(null)).toBe('');
  });
});
