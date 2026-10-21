// RIASEC yo'nalishlari matnlari (uz/ru/en). Qat'iy kasb hukmi YO'Q — faqat
// "sinab ko'rish mumkin" ohangida (siyosat: texts-policy.spec.ts).
// Matn bola va ota-onaga bir xil ko'rinadi — shuning uchun shaxssiz ifoda.

import type { RiasecCode } from './catalog';
import type { L } from './localized';

export interface RiasecText {
  /** O'lcham nomi (grafik / ro'yxat uchun). */
  name: L;
  title: L;
  body: L;
  suggestions: readonly L[];
}

export const RIASEC_TEXTS: Readonly<Record<RiasecCode, RiasecText>> = {
  R: {
    name: { uz: 'Amaliy', ru: 'Практический', en: 'Realistic' },
    title: { uz: 'Amaliy yo‘nalish', ru: 'Практическое направление', en: 'Hands-on direction' },
    body: {
      uz: 'Qo‘l bilan ishlash, texnika va aniq natija beradigan ishlarga qiziqish yuqori. Quyidagi yo‘nalishlarni sinab ko‘rish mumkin.',
      ru: 'Высокий интерес к работе руками, технике и делам с осязаемым результатом. Можно попробовать такие направления.',
      en: 'Strong interest in hands-on work, machines and tasks with a tangible result. These directions are worth trying.',
    },
    suggestions: [
      { uz: 'muhandislik', ru: 'инженерия', en: 'engineering' },
      { uz: 'texnika va mexanika', ru: 'техника и механика', en: 'technology and mechanics' },
      { uz: 'qurilish va arxitektura', ru: 'строительство и архитектура', en: 'construction and architecture' },
      { uz: 'tabiat va qishloq xo‘jaligi', ru: 'природа и сельское хозяйство', en: 'nature and agriculture' },
    ],
  },
  I: {
    name: { uz: 'Tadqiqotchi', ru: 'Исследовательский', en: 'Investigative' },
    title: { uz: 'Tadqiqotchi yo‘nalish', ru: 'Исследовательское направление', en: 'Investigative direction' },
    body: {
      uz: 'Savol berish, tahlil qilish va muammolarni yechishga qiziqish yuqori. Quyidagi yo‘nalishlarni sinab ko‘rish mumkin.',
      ru: 'Высокий интерес к вопросам, анализу и решению задач. Можно попробовать такие направления.',
      en: 'Strong interest in asking questions, analysing and solving problems. These directions are worth trying.',
    },
    suggestions: [
      { uz: 'dasturlash', ru: 'программирование', en: 'programming' },
      { uz: 'tabiiy fanlar va tajribalar', ru: 'естественные науки и эксперименты', en: 'science and experiments' },
      { uz: 'ma’lumotlar tahlili', ru: 'анализ данных', en: 'data analysis' },
      { uz: 'tibbiyot va biologiya', ru: 'медицина и биология', en: 'medicine and biology' },
    ],
  },
  A: {
    name: { uz: 'Ijodiy', ru: 'Творческий', en: 'Artistic' },
    title: { uz: 'Ijodiy yo‘nalish', ru: 'Творческое направление', en: 'Creative direction' },
    body: {
      uz: 'Yangi g‘oyalar, tasvir, so‘z va ovoz orqali fikr ifodalashga qiziqish yuqori. Quyidagi yo‘nalishlarni sinab ko‘rish mumkin.',
      ru: 'Высокий интерес к новым идеям и самовыражению через образы, слова и звук. Можно попробовать такие направления.',
      en: 'Strong interest in new ideas and expressing thoughts through images, words and sound. These directions are worth trying.',
    },
    suggestions: [
      { uz: 'dizayn', ru: 'дизайн', en: 'design' },
      { uz: 'san’at va musiqa', ru: 'искусство и музыка', en: 'art and music' },
      { uz: 'jurnalistika va yozuvchilik', ru: 'журналистика и писательство', en: 'journalism and writing' },
      { uz: 'media va video', ru: 'медиа и видео', en: 'media and video' },
    ],
  },
  S: {
    name: { uz: 'Ijtimoiy', ru: 'Социальный', en: 'Social' },
    title: { uz: 'Ijtimoiy yo‘nalish', ru: 'Социальное направление', en: 'Social direction' },
    body: {
      uz: 'Odamlarga yordam berish, tushuntirish va birga ishlashga qiziqish yuqori. Quyidagi yo‘nalishlarni sinab ko‘rish mumkin.',
      ru: 'Высокий интерес к помощи людям, объяснению и совместной работе. Можно попробовать такие направления.',
      en: 'Strong interest in helping people, explaining things and working together. These directions are worth trying.',
    },
    suggestions: [
      { uz: 'ta’lim va murabbiylik', ru: 'образование и наставничество', en: 'education and mentoring' },
      { uz: 'tibbiyot va g‘amxo‘rlik', ru: 'медицина и забота', en: 'healthcare and care' },
      { uz: 'psixologiya', ru: 'психология', en: 'psychology' },
      { uz: 'ijtimoiy loyihalar', ru: 'социальные проекты', en: 'social projects' },
    ],
  },
  E: {
    name: { uz: 'Tashabbuskor', ru: 'Предприимчивый', en: 'Enterprising' },
    title: { uz: 'Tashabbuskor yo‘nalish', ru: 'Предпринимательское направление', en: 'Enterprising direction' },
    body: {
      uz: 'Boshqalarni ilhomlantirish, ishni tashkil qilish va mas’uliyat olishga qiziqish yuqori. Quyidagi yo‘nalishlarni sinab ko‘rish mumkin.',
      ru: 'Высокий интерес к тому, чтобы вдохновлять других, организовывать дела и брать ответственность. Можно попробовать такие направления.',
      en: 'Strong interest in inspiring others, organising work and taking responsibility. These directions are worth trying.',
    },
    suggestions: [
      { uz: 'tadbirkorlik', ru: 'предпринимательство', en: 'entrepreneurship' },
      { uz: 'loyiha boshqaruvi', ru: 'управление проектами', en: 'project management' },
      { uz: 'marketing va savdo', ru: 'маркетинг и продажи', en: 'marketing and sales' },
      { uz: 'notiqlik va jamoat ishlari', ru: 'ораторство и общественная работа', en: 'public speaking and community work' },
    ],
  },
  C: {
    name: { uz: 'Tartibli', ru: 'Организационный', en: 'Conventional' },
    title: { uz: 'Tartibli yo‘nalish', ru: 'Организационное направление', en: 'Organised direction' },
    body: {
      uz: 'Reja, tartib, aniqlik va ma’lumotlar bilan ishlashga qiziqish yuqori. Quyidagi yo‘nalishlarni sinab ko‘rish mumkin.',
      ru: 'Высокий интерес к плану, порядку, точности и работе с данными. Можно попробовать такие направления.',
      en: 'Strong interest in plans, order, accuracy and working with information. These directions are worth trying.',
    },
    suggestions: [
      { uz: 'moliya va buxgalteriya', ru: 'финансы и бухгалтерия', en: 'finance and accounting' },
      { uz: 'ma’lumotlar bilan ishlash', ru: 'работа с информацией', en: 'working with records and data' },
      { uz: 'logistika', ru: 'логистика', en: 'logistics' },
      { uz: 'ma’muriy boshqaruv', ru: 'администрирование', en: 'administration' },
    ],
  },
};
