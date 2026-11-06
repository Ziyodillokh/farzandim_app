// Best-effort push yo'llarida xatoni logga yozish uchun xavfsiz yorliq: faqat turi (va Prisma kodi).
// Prisma xabarlari so'rov argumentlarini (ism, matn) o'z ichiga olishi mumkin — shuning uchun `message` log qilinmaydi.

export function errorLabel(err: unknown): string {
  if (!(err instanceof Error)) return 'noma\'lum xato';
  const code = (err as { code?: unknown }).code;
  return typeof code === 'string' ? `${err.name} ${code}` : err.name;
}
