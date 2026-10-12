import type { DeepString } from '../types';
import type { profile as uz } from '../uz/profile';

export const profile: DeepString<typeof uz> = {
  title: 'Мой профиль',
  subtitle: 'Личные данные и фото профиля',
  photo: {
    title: 'Фото профиля',
    upload: 'Загрузить фото',
    replace: 'Заменить',
    remove: 'Удалить',
    hint: 'JPG, PNG или WebP, до 8 МБ. Фото будет обрезано до квадрата.',
    portraitNote: 'Пока фото не загружено, показывается рисованный портрет.',
    uploaded: 'Фото обновлено',
    removed: 'Фото удалено',
    invalid: 'Загрузите изображение JPG, PNG или WebP',
    tooLarge: 'Файл слишком большой (до 8 МБ)',
    failed: 'Не удалось загрузить фото',
  },
  fields: {
    position: 'Должность',
    role: 'Роль',
    phone: 'Телефон',
    email: 'Email',
    username: 'Логин',
  },
};
