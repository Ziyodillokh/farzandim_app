import type { DeepString } from '../types';
import type { nav as uz } from '../uz/nav';

export const nav: DeepString<typeof uz> = {
  groups: {
    overview: 'Общее',
    domains: 'Направления',
    tools: 'Инструменты',
  },
  dashboard: 'Обзор',
  regions: 'Регионы',
  region: 'Профиль региона',
  schools: 'Школы',
  mastery: 'Успеваемость',
  iq: 'IQ и мышление',
  interests: 'Интересы',
  wellbeing: 'Благополучие и проблемы',
  attendance: 'Посещаемость',
  digital: 'Цифровые привычки',
  reports: 'Отчёты',
  methodology: 'Методология',
  present: 'Режим презентации',
  settings: 'Настройки',
};
