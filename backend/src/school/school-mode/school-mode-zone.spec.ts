import { emergencyLive } from './school-mode-store';
import { zoneOf } from './school-mode-sync.service';

describe('emergencyLive — favqulodda o\'chirish muddati', () => {
  const now = new Date('2026-11-12T06:00:00Z'); // Toshkent 11:00

  it('faol va muddati o\'tmagan — kuchda; o\'tgan — tugagan', () => {
    expect(emergencyLive({ active: true, until: new Date('2026-11-12T19:00:00Z'), at: now }, now)).toBe(true);
    expect(emergencyLive({ active: true, until: new Date('2026-11-12T05:59:00Z'), at: now }, now)).toBe(false);
    expect(emergencyLive({ active: false, until: new Date('2026-11-12T19:00:00Z'), at: now }, now)).toBe(false);
  });

  it('`until`siz eski yozuv — faqat yoqilgan kuni (Toshkent)', () => {
    expect(emergencyLive({ active: true, until: null, at: new Date('2026-11-12T01:00:00Z') }, now)).toBe(true);
    expect(emergencyLive({ active: true, until: null, at: new Date('2026-11-11T18:30:00Z') }, now)).toBe(false); // 23:30 kecha
    expect(emergencyLive({ active: true, until: null, at: null }, now)).toBe(false);
  });
});

describe('zoneOf — jadvalga hudud', () => {
  const school = { latitude: 41.3, longitude: 69.2, zoneRadiusM: 150 };

  it('faqat «faqat hududda» yoqilgan va hudud to\'liq bo\'lsa', () => {
    expect(zoneOf({ zoneRequired: true }, school)).toEqual({ latitude: 41.3, longitude: 69.2, radiusM: 150 });
    expect(zoneOf({ zoneRequired: false }, school)).toBeNull();
    expect(zoneOf({ zoneRequired: true }, { ...school, zoneRadiusM: null })).toBeNull();
    expect(zoneOf({ zoneRequired: true }, { ...school, latitude: null })).toBeNull();
  });
});
