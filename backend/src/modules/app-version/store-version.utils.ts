/**
 * Do'kon javobidan versiya ajratish — SOF funksiyalar (test qilinadi).
 *
 * Bu mantiq alohida turadi, chunki u eng xavfli joy: noto'g'ri ajratilgan
 * qiymat foydalanuvchiga SOXTA "yangilanish bor" bildirishnomasini
 * ko'rsatadi (2026-08-26'da aynan shunday bo'lgan) yoki aksincha, haqiqiy
 * relizni yashiradi (2026-09-05, iOS 1.0.1).
 */

/** Faqat `x.y` yoki `x.y.z`. Boshqasi ishonchsiz deb rad etiladi. */
export const VERSION_RE = /^\d+\.\d+(\.\d+)?$/;

export function isValidVersion(v: string | null | undefined): v is string {
  return typeof v === 'string' && VERSION_RE.test(v);
}

/** `1.0.10` > `1.0.9` bo'lishi uchun raqamli (leksik emas) taqqoslash. */
export function compareVersions(a: string, b: string): number {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    const x = pa[i] ?? 0;
    const y = pb[i] ?? 0;
    if (x !== y) return x < y ? -1 : 1;
  }
  return 0;
}

/** `https://apps.apple.com/app/id6798972223` → `6798972223`. */
export function appStoreIdFromUrl(url: string): string | null {
  const m = /id(\d{6,})/.exec(url);
  return m ? m[1] : null;
}

/** iTunes Lookup JSON'idan versiyani oladi. */
export function parseAppStoreVersion(body: string): string | null {
  try {
    const data = JSON.parse(body) as {
      resultCount?: number;
      results?: { version?: string }[];
    };
    if (!data.resultCount || !data.results?.length) return null;
    const v = data.results[0].version;
    return isValidVersion(v) ? v : null;
  } catch {
    return null;
  }
}

/**
 * Play sahifasidan versiya. Rasmiy API yo'q, shuning uchun bir nechta
 * naqsh sinaladi.
 *
 * ⚠️ MO'RT: Google sahifa tuzilishini o'zgartirsa hammasi mos kelmay
 * qoladi va `null` qaytadi — bu ATAYLAB shunday. `null` = "bilmayman",
 * chaqiruvchi eski qiymatni saqlaydi. Taxmin qilib yozishdan afzal.
 */
export function parsePlayVersion(html: string): string | null {
  const patterns = [
    /\[\[\["(\d+\.\d+(?:\.\d+)*)"\]\]/,
    /"softwareVersion"\s*:\s*"(\d+\.\d+(?:\.\d+)*)"/,
    /Current Version.{0,120}?(\d+\.\d+(?:\.\d+)*)/s,
  ];
  for (const re of patterns) {
    const m = re.exec(html);
    if (m?.[1] && isValidVersion(m[1])) return m[1];
  }
  return null;
}

/**
 * Yangi qiymatni qabul qilish kerakmi?
 *
 * Qoida: yaroqli semver bo'lsin VA ma'lum qiymatdan past bo'lmasin.
 * Pastga tushirish taqiqlangan — sahifa vaqtincha noto'g'ri o'qilsa
 * foydalanuvchiga mavjud bo'lmagan "yangilanish" ko'rsatilmasin.
 */
export function shouldAccept(
  found: string | null | undefined,
  known: string | null | undefined,
): boolean {
  if (!isValidVersion(found)) return false;
  if (!known) return true;
  if (!isValidVersion(known)) return true;
  return compareVersions(found, known) >= 0;
}
