/**
 * Konkurs (test) fanlari — sehrgar va tahrirlash oynasi uchun YAGONA ro'yxat.
 *
 * Avval ikkala komponentda alohida 6 talik nusxa bor edi va unda Biologiya,
 * Geografiya, Tarix yo'q edi — shuning uchun prod'da "Biologiya 9-sinf" testi
 * `subject: "Kimyo"` bilan saqlangan. Backend `subject`ni erkin satr sifatida
 * qabul qiladi (MaxLength 50), cheklov faqat shu UI ro'yxatida.
 *
 * Bola ilovasi ikonka/rangni `contestSubjectKey()` (farzandim_child,
 * contest_model.dart) orqali prefiks bo'yicha tanlaydi — shu nomlar o'sha
 * kalitlarga mos: "Ingliz tili" → ingliz, "IT / Mantiq" → it va h.k.
 */
export const OLYMPIAD_SUBJECTS = [
  'Matematika',
  'Ona tili',
  'Ingliz tili',
  'Fizika',
  'Kimyo',
  'Biologiya',
  'Geografiya',
  'Tarix',
  'IT / Mantiq',
] as const;

export type OlympiadSubject = (typeof OLYMPIAD_SUBJECTS)[number];

/**
 * Select uchun variantlar: ro'yxatda bo'lmagan mavjud qiymat (masalan API
 * orqali kiritilgan "Astronomiya") yo'qolib ketmasin — uni ham qo'shamiz.
 */
export function subjectOptions(current?: string | null): string[] {
  const list: string[] = [...OLYMPIAD_SUBJECTS];
  const cur = (current ?? '').trim();
  if (cur && !list.includes(cur)) list.push(cur);
  return list;
}
