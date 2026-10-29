import type { DeepString } from '../types';
import type { filters as uz } from '../uz/filters';

export const filters: DeepString<typeof uz> = {
  period: 'Период',
  grades: 'Классы',
  gender: 'Пол',
  schoolType: 'Тип школы',
  periodHint: 'Сравнение — с тем же периодом прошлого года',
  quarterLabel: '{ay} учебный год, {q}-я четверть',
  ayLabel: '{ay} учебный год',
  active: 'Активные фильтры',
};
