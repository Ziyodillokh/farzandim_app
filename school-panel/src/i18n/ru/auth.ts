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
  demoAccountsHint: 'Нажмите на карточку — сразу войдёте с этой ролью.',
  oneClick: 'или в один клик под демо-аккаунтом',
  loginAs: 'Войти как {role}',
  slogan: 'От защиты — к взлёту',
  heroTitle: 'Школе — управление, родителям — спокойствие, ученику — безопасная среда',
  heroPoints: {
    schoolMode: 'Порядок использования телефонов во время уроков',
    attendance: 'Надёжный учёт входа и выхода с уведомлением родителей',
    care: 'Голос ребёнка — конфиденциальная и защищённая помощь',
  },
  forbiddenTitle: 'Нет доступа',
  forbiddenText: 'Этот раздел закрыт для вашей роли.',
  forbiddenSection: 'Раздел «{section}» закрыт для роли «{role}».',
  forbiddenAllowed: 'Доступ есть у ролей: {roles}.',
  forbiddenAdvice: {
    DIRECTOR: 'Права ролей заданы политикой школы: этот раздел относится к задачам другого сотрудника или закрыт ради конфиденциальности.',
    ADMIN: 'При необходимости обратитесь к директору школы.',
    STAFF: 'При необходимости обратитесь к директору или администратору школы.',
  },
  forbiddenLinks: 'Доступные вам разделы',
  forbiddenBack: 'Вернуться на главную',
  sessionExpired: 'Сессия истекла, войдите снова',
  welcome: 'Добро пожаловать, {name}!',
};
