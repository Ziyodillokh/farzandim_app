import type { DeepString } from '../types';
import type { errors as uz } from '../uz/errors';

export const errors: DeepString<typeof uz> = {
  FORBIDDEN: 'У вас нет прав на это действие',
  NOT_FOUND: 'Данные не найдены',
  VALIDATION: 'Данные заполнены неверно',
  CONFLICT: 'Такая запись уже существует',
  UNKNOWN: 'Непредвиденная ошибка. Попробуйте ещё раз',
  storageFull: 'Память браузера заполнена — изменения сохранятся только в этой сессии',
  form: {
    required: 'Обязательное поле',
    tooShort: 'Минимум {min} символов',
    tooLong: 'Максимум {max} символов',
    invalidPhone: 'Телефон: +998 XX XXX XX XX',
    invalidEmail: 'Неверный email',
    invalidTime: 'Время: ЧЧ:ММ',
    invalidDate: 'Неверная дата',
    endBeforeStart: 'Время окончания должно быть позже начала',
    selectAtLeastOne: 'Выберите хотя бы один вариант',
  },
};
