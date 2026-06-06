/**
 * Haqiqiy klient IP'sini aniqlaydi (nginx orqasida).
 *
 * trustProxy yoqilgan (main.ts) — Fastify `request.ip` X-Forwarded-For'ning
 * eng chap (asl klient) IP'sini qaytaradi. Baribir header'dan ham fallback
 * o'qiymiz va IPv4-mapped IPv6 (`::ffff:`) prefiksini olib tashlaymiz.
 */
export function getClientIp(req: any): string {
  const xff = req?.headers?.['x-forwarded-for'];
  let ip = '';
  if (typeof xff === 'string' && xff.length > 0) {
    ip = xff.split(',')[0]!.trim();
  } else if (Array.isArray(xff) && xff.length > 0) {
    ip = String(xff[0]).split(',')[0]!.trim();
  } else {
    ip = req?.ip || req?.socket?.remoteAddress || '';
  }
  return String(ip).replace(/^::ffff:/, '').trim();
}
