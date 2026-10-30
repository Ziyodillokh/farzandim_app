import type { DeepString } from '../types';
import type { shell as uz } from '../uz/shell';

export const shell: DeepString<typeof uz> = {
  expand: 'Открыть меню',
  account: 'Аккаунт',
  language: 'Язык',
  theme: 'Тема',
  themeLight: 'Светлая',
  themeDark: 'Тёмная',
  searchHint: 'Поиск страницы или региона…',
  searchShortcut: '⌘K',
  commandPages: 'Страницы',
  commandRegions: 'Регионы',
  commandEmpty: 'Ничего не найдено',
  poweredBy: 'FARZANDIM TECH',
  scopeNational: 'Республика Узбекистан',
  scopeNationalSub: '14 регионов · 206 районов',
  scopeRegionalSub: 'Региональный уровень',
  roles: {
    NATIONAL: 'Республика',
    REGIONAL: 'Регион',
  },
  filters: 'Фильтры',
  resetFilters: 'Сбросить фильтры',
  fullscreen: 'Полный экран',
  liveData: 'Онлайн',
};
