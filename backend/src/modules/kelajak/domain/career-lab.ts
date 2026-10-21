// Career Lab faoliyatlarining qisqa nomlari (uz/ru/en) — bank savollari uchun.
// RIASEC kodi esa ma'lumotda: `scoring.riasec` (review-overrides.json →
// migratsiya / import; admin paneldan ham belgilanadi). Umumiy refleksiya
// savollari (Q193, Q208, Q210–Q212) bitta yo'nalishga tegishli emas — kodsiz
// (docs/KELAJAK-REJA.md §3). Xaritada yo'q savol nomi — savol matni.

import type { L } from './localized';

export const CAREER_LAB_LABELS: Readonly<Record<string, L>> = {
  // 7–9 yosh
  'PARVOZ-Q193': { uz: 'Kasb bo‘yicha rol o‘yini', ru: 'Ролевая игра о профессии', en: 'Career role-play' },
  'PARVOZ-Q194': { uz: 'Biror narsa yasash', ru: 'Сделать что-то своими руками', en: 'Making something' },
  'PARVOZ-Q195': { uz: 'Boshqalarga yordam berish', ru: 'Помощь другим', en: 'Helping others' },
  'PARVOZ-Q196': {
    uz: 'Rasm yoki hikoya yaratish',
    ru: 'Рисунок или рассказ',
    en: 'Creating a picture or story',
  },
  'PARVOZ-Q197': { uz: 'Muammoni yechish', ru: 'Решение задачи', en: 'Solving a problem' },
  // 10–12 yosh
  'PARVOZ-Q198': {
    uz: 'Kichik tajriba o‘tkazish',
    ru: 'Небольшой эксперимент',
    en: 'Running a small experiment',
  },
  'PARVOZ-Q199': { uz: 'Jamoaviy loyiha', ru: 'Командный проект', en: 'Team project' },
  'PARVOZ-Q200': {
    uz: 'Mahsulot yoki maket yaratish',
    ru: 'Создание изделия или макета',
    en: 'Building a product or model',
  },
  'PARVOZ-Q201': {
    uz: 'Mavzuni boshqalarga tushuntirish',
    ru: 'Объяснить тему другим',
    en: 'Explaining a topic to others',
  },
  'PARVOZ-Q202': {
    uz: 'Reja va tartib talab qiladigan ish',
    ru: 'Задание на порядок и план',
    en: 'A task that needs order and planning',
  },
  // 13–15 yosh
  'PARVOZ-Q203': {
    uz: 'Dasturlash yoki mantiqiy topshiriq',
    ru: 'Программирование или логика',
    en: 'Coding or logic task',
  },
  'PARVOZ-Q204': {
    uz: 'Dizayn yoki kontent yaratish',
    ru: 'Дизайн или контент',
    en: 'Design or content creation',
  },
  'PARVOZ-Q205': {
    uz: 'Tadbir yoki jamoani boshqarish',
    ru: 'Организация события или команды',
    en: 'Leading an event or team',
  },
  'PARVOZ-Q206': {
    uz: 'Tadqiqot va ma’lumot tahlili',
    ru: 'Исследование и анализ данных',
    en: 'Research and data analysis',
  },
  'PARVOZ-Q207': {
    uz: 'Xizmat ko‘rsatish yoki maslahat berish',
    ru: 'Обслуживание или консультация',
    en: 'Serving or advising people',
  },
  // 16–18 yosh
  'PARVOZ-Q208': {
    uz: 'Kasbga yaqin amaliy topshiriq',
    ru: 'Практическое задание по профессии',
    en: 'Hands-on career task',
  },
  'PARVOZ-Q209': {
    uz: 'Loyiha uchun mas’uliyat olish',
    ru: 'Ответственность за проект',
    en: 'Taking charge of a project',
  },
  'PARVOZ-Q210': {
    uz: 'Kasbning kundalik vazifalari',
    ru: 'Повседневные задачи профессии',
    en: 'Everyday tasks of a career',
  },
  'PARVOZ-Q211': {
    uz: 'Yo‘nalishda yana tajriba',
    ru: 'Ещё одна проба в направлении',
    en: 'Another try in the field',
  },
  'PARVOZ-Q212': { uz: 'Sinovdan keyingi reja', ru: 'План после пробы', en: 'Plans after the trial' },
};

/** Faoliyat nomi (xaritada yo'q — admin qo'shgan savol — `null`, o'rniga savol matni). */
export function careerLabLabel(externalId: string): L | null {
  return Object.prototype.hasOwnProperty.call(CAREER_LAB_LABELS, externalId)
    ? CAREER_LAB_LABELS[externalId]
    : null;
}
