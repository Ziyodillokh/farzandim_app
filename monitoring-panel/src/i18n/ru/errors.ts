import type { DeepString } from '../types';
import type { errors as uz } from '../uz/errors';

export const errors: DeepString<typeof uz> = {
  load: 'Не удалось загрузить данные',
  notFound: 'Страница не найдена',
  notFoundText: 'Неверный адрес или страница перемещена.',
  unknownRegion: 'Регион не найден',
};
