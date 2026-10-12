import type { StaffNotification } from '@/data/contracts';
import { allowedClassIds, type Actor } from './context';
import type { Tables } from './tables';

/** Saqlanadigan bildirishnomalar soni chegarasi (eng eskilari tashlanadi). */
export const MAX_NOTIFICATIONS = 200;

/** Qo'shish yoki yangilash (bir xil id — almashtiriladi). */
export function pushNotification(t: Tables, n: Omit<StaffNotification, 'id'> & { id?: string }): StaffNotification {
  const item: StaffNotification = { ...n, id: n.id ?? `ntf-${n.kind.toLowerCase()}-${Date.parse(n.at) || Date.now()}` };
  const rest = (t.notifications ?? []).filter((x) => x.id !== item.id);
  t.notifications = [...rest, item].slice(-MAX_NOTIFICATIONS);
  return item;
}

/** Foydalanuvchi ko'ra oladigan saqlangan bildirishnomalar (rol va sinf doirasi bo'yicha). */
export function notificationsFor(t: Tables, actor: Actor): StaffNotification[] {
  const allowed = allowedClassIds(actor);
  return (t.notifications ?? []).filter(
    (n) => n.roles.includes(actor.role) && (n.classIds === null || !allowed || n.classIds.some((c) => allowed.includes(c))),
  );
}

/** So'nggi `windowHours` soatdagi faol xavfsizlik signallari soni (bosh sahifa ogohlantirishi uchun). */
export function activeSafetySignals(t: Tables, actor: Actor, nowMs: number, windowHours = 24): number {
  const from = nowMs - windowHours * 3_600_000;
  return notificationsFor(t, actor).filter((n) => n.kind === 'SAFETY_SIGNAL' && Date.parse(n.at) >= from && Date.parse(n.at) <= nowMs).length;
}
