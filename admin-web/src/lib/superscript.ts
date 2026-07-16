/**
 * `x^2` → `x²` — daraja yozuvini Unicode yuqori indeksga aylantiradi.
 *
 * NEGA KERAK: savol matni oddiy matn maydoni (`<Textarea>`). Word yoki PDF'dan
 * nusxa olinganda `x²` dagi yuqori indeks BELGI emas, FORMATLASH bo'lgani uchun
 * yo'qoladi va `x2` bo'lib qoladi ("y=x2−4x+3"). Shuning uchun admin darajani
 * `x^2` deb yozadi — bu funksiya uni `x²` ga aylantiradi.
 *
 * Natija oddiy matn: backend matnga tegmaydi (faqat uzunlik tekshiruvi), bola
 * ilovasi ham uni shundayligicha chizadi — qo'shimcha render kerak emas.
 * Shrift belgini qo'llab-quvvatlamasa Flutter tizim shriftiga qaytadi.
 */

const SUP: Record<string, string> = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  '-': '⁻',
  '+': '⁺',
  n: 'ⁿ',
  i: 'ⁱ',
};

/**
 * Qo'llab-quvvatlanadigan yozuvlar: `x^2`, `x^-3`, `x^12`, `x^(12)`, `x^n`.
 *
 * Aylantirib bo'lmaydigan yozuv (masalan `x^y`) o'z holicha qoladi — jim
 * buzib qo'ymaslik uchun.
 */
export function toSuperscript(text: string): string {
  return text.replace(/\^\(?([-+]?\d+|[ni])\)?/g, (match, group: string) => {
    const out = [...group].map((ch) => SUP[ch]);
    return out.every(Boolean) ? out.join('') : match;
  });
}
