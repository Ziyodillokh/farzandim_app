import type { NotificationItem, OpenRequests } from '@/data/contracts';
import type { Actor } from '../context';
import type { Tables } from '../tables';

/** Rolga mos "ochiq so'rovlar" (bosh sahifa KPI) — agent C to'ldiradi. */
export function openRequests(_tables: Tables, _actor: Actor): OpenRequests | null {
  void _tables;
  void _actor;
  return null;
}

/** Bildirishnomalar markazi (agent C to'ldiradi). */
export const notificationsService = {
  async feed(): Promise<NotificationItem[]> {
    return [];
  },
};
