import type { DeepString } from '../types';
import type { demo as uz } from '../uz/demo';

export const demo: DeepString<typeof uz> = {
  clockTitle: 'Демо-время',
  clockReal: 'Реальное время',
  clockScenario: 'Демо-день (с 07:45)',
  clockHint: 'Показывает утренние приходы вживую даже вечером или в выходной.',
  speed: 'Скорость',
  restartMorning: 'Начать утро заново',
  panelTitle: 'Управление демо',
  panelHint: 'Вызов событий вручную во время презентации (Ctrl + Shift + D).',
  triggerLate: 'Опоздание',
  triggerEarlyExit: 'Запрос на ранний уход',
  triggerCareUrgent: 'Срочное обращение',
  triggerVerification: 'Запрос родителя на проверку',
  triggered: 'Событие создано',
  resetTitle: 'Сбросить демо-данные',
  resetText: 'Все изменения будут удалены, демо-школа вернётся в исходное состояние. Название и логотип школы сохранятся.',
  resetDone: 'Демо-данные сброшены',
  bannerText: 'Это демо: все имена и данные вымышлены.',
};
