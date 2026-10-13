// ─────────────────────────────────────────────────────────────────────
// trust-proxy — Fastify `trustProxy` qiymati (TRUST_PROXY env)
// ─────────────────────────────────────────────────────────────────────
//
// Backend nginx ortida, xuddi shu serverda (127.0.0.1) ishlaydi. Avval
// `trustProxy: true` edi — Fastify X-Forwarded-For'ning ENG CHAP qiymatini
// `request.ip` deb olardi, nginx esa `$proxy_add_x_forwarded_for` bilan
// klient yuborgan header'ni saqlab qoladi. Natijada har so'rovda soxta
// X-Forwarded-For yuborib child-pair rate-limit'ini, admin IP allowlist'ini
// va webhook IP guard'ini chetlab o'tish mumkin edi (App Store audit F41).
//
// Endi faqat lokal proksi (loopback) ishonchli: `request.ip` = nginx'ga
// ulangan haqiqiy klient IP'si (X-Forwarded-For'ning O'NG tomondagi,
// nginx qo'shgan qiymati). CDN (masalan Cloudflare) qo'shilsa, uning IP
// diapazonlarini TRUST_PROXY'ga vergul bilan qo'shing.
//
// Qiymatlar: bo'sh → 'loopback' | 'false' → hech kimga ishonmaslik |
// raqam → hop soni | 'true' → hammaga (XAVFLI, tavsiya etilmaydi) |
// boshqa matn → IP/CIDR/preset ro'yxati (masalan '127.0.0.1,10.0.0.0/8').

export const DEFAULT_TRUST_PROXY = 'loopback';

export function resolveTrustProxy(raw?: string): boolean | number | string {
  const value = raw?.trim() ?? '';
  if (value.length === 0) return DEFAULT_TRUST_PROXY;
  if (value === 'false') return false;
  if (value === 'true') return true;
  if (/^\d+$/.test(value)) return Number(value);
  return value;
}
