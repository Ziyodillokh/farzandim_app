// ─────────────────────────────────────────────────────────────────────
// content-filter — AI hamroh xavfsizlik filtri (#69)
// ─────────────────────────────────────────────────────────────────────
//
// Kiruvchi (bola) va chiquvchi (AI) matnni xavfli/nojo'ya mavzularga
// tekshiradi. Topilsa `flagged=true` va xavfsiz javob beriladi (Claude
// chaqirilmaydi). Bu birinchi mudofaa qatlami — system prompt ikkinchisi.
//
// Ataylab KENG (false-positive ham bo'lishi mumkin) — bolalar xavfsizligida
// ehtiyotkorlik ustun. O'zbek (lotin), rus va ingliz kalit so'zlari.

/** Xavfli kalit so'z/iboralar — kichik harfga keltirilgan matn ichida qidiriladi. */
const DANGER_PATTERNS: RegExp[] = [
  // O'z joniga qasd / o'z-o'ziga zarar
  /o'?z[io']?ni\s+o'?ldir/i,
  /o'?zimni\s+o'?ldir/i,
  /\bsuicid/i,
  /\bo'?lib\s+qol/i,
  /jonimga\s+qasd/i,
  /venamni|venani\s+kes/i,
  /убить\s+себя|суицид|покончить/i,
  /kill\s+myself|self[-\s]?harm|cut\s+myself/i,
  // Zo'ravonlik / qurol
  /\bbomba\b|portlovchi|portlatish/i,
  /\bqurol\b|\bpiston\b|o'?q\s*-?\s*dori/i,
  /\bo'?ldir(ish|aman|amiz)\b/i,
  /\bgun\b|\bweapon\b|\bbomb\b|how\s+to\s+kill/i,
  /\bоружие\b|\bбомба\b|убить\b/i,
  // Jinsiy / kattalar mazmuni
  /jinsiy\s+(aloqa|munosabat)/i,
  /\bseks\b|\bsex\b|\bporno?\b|\bpornhub\b/i,
  /\bnude\b|\bnaked\b/i,
  /\bпорно\b|\bсекс\b/i,
  // Giyohvandlik / spirtli
  /giyohvand|narkotik|\bnasha\b|\bchars\b|\bgeroin\b|\bkokain\b/i,
  /\bdrugs?\b|\bmarijuana\b|\bcocaine\b|\bheroin\b/i,
  /\bнаркотик|\bгашиш\b/i,
  // Nafrat / kamsitish (qisqa)
  /how\s+to\s+(make|build)\s+(a\s+)?(bomb|weapon|gun)/i,
];

export interface FilterResult {
  flagged: boolean;
}

/** Matnni xavfli mavzularga tekshiradi. */
export function screenContent(text: string): FilterResult {
  if (!text) return { flagged: false };
  const lower = text.toLowerCase();
  for (const re of DANGER_PATTERNS) {
    if (re.test(lower)) return { flagged: true };
  }
  return { flagged: false };
}

/** Xavfli mavzuda beriladigan xavfsiz, mehribon javob (o'zbekcha). */
export const SAFE_REDIRECT_REPLY =
  "Bu mavzuda men yordam bera olmayman. Iltimos, bu haqda ota-onang yoki " +
  "ishonchli katta odam bilan gaplash — ular senga yordam berishadi. 💚";
