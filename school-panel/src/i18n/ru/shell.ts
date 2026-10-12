import type { DeepString } from '../types';
import type { shell as uz } from '../uz/shell';

export const shell: DeepString<typeof uz> = {
  searchHint: 'Найдите ученика, класс, сотрудника или страницу…',
  searchShortcut: '⌘K',
  commandEmpty: 'Ничего не найдено',
  commandPages: 'Страницы',
  commandStudents: 'Ученики',
  commandClasses: 'Классы',
  commandStaff: 'Сотрудники',
  language: 'Язык',
  theme: 'Тема',
  themeLight: 'Светлая',
  themeDark: 'Тёмная',
  themeSystem: 'Системная',
  profile: 'Профиль',
  role: 'Роль',
  collapse: 'Свернуть меню',
  expand: 'Развернуть меню',
  poweredBy: 'Экосистема Parvoz',
  schoolDay: 'Учебный день',
  holiday: 'Выходной день',
};
