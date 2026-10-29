import type { DeepString } from '../types';
import type { region as uz } from '../uz/region';

export const region: DeepString<typeof uz> = {
  title: 'Профиль региона',
  subtitle: 'По районам и в сравнении с республикой',
  eyebrow: 'Профиль региона',
  back: 'Все регионы',
  backDashboard: 'Общий обзор',
  switch: 'Другой регион',
  ranksTitle: 'Место в республике',
  rank: '{rank}/{total}',
  rankHint: '1 — лучший результат',
  notFound: 'Регион не найден',
  notFoundText: 'Ссылка неверна или устарела. Выберите регион из списка или на карте.',
  notFoundAction: 'Список регионов',
};
