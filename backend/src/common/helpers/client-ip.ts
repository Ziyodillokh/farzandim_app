/**
 * Haqiqiy klient IP'sini aniqlaydi (nginx orqasida).
 *
 * Fastify `trustProxy` faqat lokal proksiga ishonadi (main.ts,
 * helpers/trust-proxy.ts) — shuning uchun `request.ip` nginx'ga ulangan
 * haqiqiy klient IP'si. X-Forwarded-For header'ini bu yerda O'ZIMIZ
 * O'QIMAYMIZ: uning chap qismi klient tomonidan soxtalashtirilishi mumkin
 * (avval aynan shu sabab admin IP allowlist'ini chetlab o'tish mumkin edi —
 * App Store audit F41). IPv4-mapped IPv6 (`::ffff:`) prefiksi olib tashlanadi.
 */
export function getClientIp(req: any): string {
  const ip = req?.ip || req?.socket?.remoteAddress || '';
  return String(ip).replace(/^::ffff:/, '').trim();
}
