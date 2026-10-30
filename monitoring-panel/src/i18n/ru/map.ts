import type { DeepString } from '../types';
import type { map as uz } from '../uz/map';

export const map: DeepString<typeof uz> = {
  title: 'Карта регионов',
  metric: 'Показатель',
  legendBetter: 'лучше',
  legendWorse: 'хуже',
  legendLow: 'ниже',
  legendHigh: 'выше',
  quantileNote: 'цвета — 5 групп по рейтингу',
  noData: 'нет данных',
  clickHint: 'Нажмите на регион — подробный профиль',
  districtsTitle: 'Карта районов',
  districtsNoShape: 'Нет границ на карте (образованы после 2020 г.): {names}',
  ranking: 'Рейтинг',
  top: 'Лучшие',
  bottom: 'Требуют внимания',
  attribution: 'Границы: Natural Earth (открытые данные), районы: OCHA ROCCA 2020 (CC BY 3.0 IGO) · geoBoundaries',
};
