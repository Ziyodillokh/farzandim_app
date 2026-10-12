import type { DeepString } from '../types';
import type { auth as uz } from '../uz/auth';

export const auth: DeepString<typeof uz> = {
  title: 'Вход в панель',
  subtitle: 'Введите логин и пароль учётной записи вашей школы.',
  username: 'Логин',
  usernamePlaceholder: 'например, direktor',
  password: 'Пароль',
  passwordPlaceholder: '••••••••',
  submit: 'Войти',
  invalid: 'Неверный логин или пароль',
  logout: 'Выйти',
  demoAccounts: 'Демо-аккаунты',
  demoAccountsHint: 'Выберите роль — поля заполнятся автоматически.',
  heroTitle: 'Школе — управление, родителям — спокойствие, ученику — безопасная среда',
  heroPoints: {
    schoolMode: 'Порядок использования телефонов во время уроков',
    attendance: 'Надёжный учёт входа и выхода с уведомлением родителей',
    care: 'Голос ребёнка — конфиденциальная и защищённая помощь',
  },
  forbiddenTitle: 'Нет доступа',
  forbiddenText: 'Этот раздел закрыт для вашей роли. При необходимости обратитесь к директору школы.',
  forbiddenBack: 'Вернуться на главную',
  sessionExpired: 'Сессия истекла, войдите снова',
  welcome: 'Добро пожаловать, {name}!',
};
