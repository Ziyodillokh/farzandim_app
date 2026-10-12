import type { DeepString } from '../types';
import type { audit as uz } from '../uz/audit';

export const audit: DeepString<typeof uz> = {
  title: 'Журнал аудита',
  subtitle: 'Кто, когда и что изменил',
};
