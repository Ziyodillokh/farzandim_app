import type { DeepString } from '../types';
import type { notifications as uz } from '../uz/notifications';

export const notifications: DeepString<typeof uz> = {
  title: 'Уведомления',
  subtitle: 'Важные события в одном месте',
  unreadCount: 'Непрочитанных: {count}',
  allRead: 'Всё прочитано',
  unread: 'Не прочитано',
  markAllRead: 'Прочитать все',
  today: 'Сегодня',
  earlier: 'Ранее',
  emptyTitle: 'Пока уведомлений нет',
  emptyHint: 'Новые запросы, обращения и сигналы появятся здесь.',
  loadError: 'Не удалось загрузить уведомления',
  loadErrorHint: 'Попробуйте ещё раз чуть позже.',
  safetyHint: 'Подробности скрыты — свяжитесь с психологом',
  kind: {
    SAFETY_SIGNAL: 'Сигнал безопасности: требуется внимание',
    TEST_COMPLETED: 'Тест завершили учеников: {count}',
    EARLY_EXIT_PENDING: '{name} ({className}) — запрос на ранний уход в {time}',
    VERIFICATION_OPEN: '{name} просит проверить оплату',
    CARE_NEW: 'Новое обращение — {className}',
    CARE_URGENT: 'Срочное обращение — {className}',
    MESSAGE_SENT: '«{title}» — отправлено получателям: {recipients}',
    EMERGENCY: 'Активен экстренный режим',
  },
  category: {
    SAFETY_SIGNAL: 'Безопасность',
    TEST_COMPLETED: 'Тест',
    EARLY_EXIT_PENDING: 'Ранний уход',
    VERIFICATION_OPEN: 'Оплата',
    CARE_NEW: 'Обращение',
    CARE_URGENT: 'Срочно',
    MESSAGE_SENT: 'Сообщение',
    EMERGENCY: 'Экстренно',
  },
};
