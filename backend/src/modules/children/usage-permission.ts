// Android bola ilovasining 1.0.19 va eskiroq versiyalarida fon xizmati
// (foreground service) dvigateli `farzandim/usage_stats` kanaliga ulanmagan:
// u har heartbeat'da `usagePermission: false` yuboradi, garchi ruxsat aslida
// yoqilgan bo'lsa ham. Bunday qiymat saqlansa ota-onaga soxta «ruxsat
// o'chirildi» push'lari ketadi va maktab panelida «Ruxsat yo'q» chiqadi.
// Shu sabab eski versiyalardan kelgan `false` e'tiborsiz qoldiriladi
// (`true` esa ishonchli — u faqat ruxsat haqiqatan bor bo'lganda keladi).

/** Fon dvigatelida ham ruxsatni to'g'ri aniqlaydigan birinchi versiya. */
export const RELIABLE_USAGE_PERMISSION_VERSION = '1.0.20';

/** `"1.0.19"` → `[1, 0, 19]`; tushunarsiz satr — `null`. */
function parseVersion(value: string): number[] | null {
  const core = value.trim().split(/[+\s-]/)[0] ?? '';
  const parts = core.split('.');
  if (parts.length === 0 || parts.some((p) => !/^\d+$/.test(p))) return null;
  return parts.map(Number);
}

/** `a < b` (semver tartibida, yetishmagan qism — 0). */
function isVersionBelow(a: number[], b: number[]): boolean {
  const length = Math.max(a.length, b.length);
  for (let i = 0; i < length; i++) {
    const x = a[i] ?? 0;
    const y = b[i] ?? 0;
    if (x !== y) return x < y;
  }
  return false;
}

/**
 * Heartbeat'dagi `usagePermission` qiymatidan saqlash va ogohlantirish uchun
 * ishonchlisini qaytaradi: eski (yoki versiyasi noma'lum) ilovadan kelgan
 * `false` — `undefined` (o'zgartirilmaydi).
 */
export function reliableUsagePermission(value: boolean | undefined, appVersion: string | null | undefined): boolean | undefined {
  if (value !== false) return value;
  const version = appVersion ? parseVersion(appVersion) : null;
  const reliable = parseVersion(RELIABLE_USAGE_PERMISSION_VERSION)!;
  if (!version || isVersionBelow(version, reliable)) return undefined;
  return false;
}
