import type { DeepString } from '../types';
import type { auth as uz } from '../uz/auth';

export const auth: DeepString<typeof uz> = {
  title: 'Вход в систему',
  subtitle: 'Закрытая аналитическая панель — только для уполномоченных сотрудников',
  username: 'Логин',
  usernamePlaceholder: 'Например: respublika',
  password: 'Пароль',
  passwordPlaceholder: 'Введите пароль',
  showPassword: 'Показать пароль',
  hidePassword: 'Скрыть пароль',
  submit: 'Войти',
  invalid: 'Неверный логин или пароль',
  oneClick: 'Демо-аккаунты — вход в один клик',
  logout: 'Выйти',
  heroEyebrow: 'Республиканский аналитический центр',
  heroTitle: 'Развитие каждого ребёнка — на одной карте',
  heroText: 'Успеваемость, IQ, интересы, благополучие, посещаемость и цифровые привычки — по регионам и районам, почти в реальном времени.',
  heroPoints: {
    map: 'Интерактивная карта: 14 регионов и 206 районов',
    signals: 'Автоматические выводы: внимание, наблюдение и позитивные сигналы',
    privacy: 'Только обобщённые данные — без имён и геолокации',
  },
  heroStats: {
    pupils: 'учащихся',
    schools: 'школ',
    regions: 'регионов',
  },
  accounts: {
    NATIONAL: 'Республиканский аналитический центр',
    REGIONAL: 'Управление образования: {region}',
  },
  forbiddenTitle: 'Нет доступа',
  forbiddenText: 'Этот раздел вне ваших полномочий. Региональный аккаунт видит только свой регион.',
  forbiddenBack: 'На главную',
};
