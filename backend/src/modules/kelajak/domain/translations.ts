// Bank matnlarining yetishmayotgan ruscha / inglizcha tarjimasini qo'shadi
// (`translations.data.ts`). Bazadagi tarjima bo'lsa — o'sha ustun; o'zbekcha
// matn o'zgargan bo'lsa (admin tahriri) tarjima topilmaydi va matn
// o'zbekcha qoladi.

import { L } from './localized';
import { KELAJAK_TRANSLATIONS } from './translations.data';

export function withTranslations(text: L): L {
  if (typeof text?.uz !== 'string') return text;
  const found = KELAJAK_TRANSLATIONS[text.uz.trim()];
  if (!found) return text;
  return { uz: text.uz, ru: text.ru || found.ru, en: text.en || found.en };
}
