import type { CareRequest, StaffNotification } from '@/data/contracts';

/**
 * Seed bildirishnomalari: faollashtirilgan xavfsizlik protokoli uchun signal.
 * Signal ichida ism, sinf yoki murojaat matni YO'Q — faqat "e'tibor kerak" fakti.
 */
export function buildNotifications(careRequests: readonly CareRequest[]): StaffNotification[] {
  return careRequests
    .filter((r) => r.protocolActivated)
    .map((r) => ({
      id: `ntf-safety-${r.id}`,
      kind: 'SAFETY_SIGNAL' as const,
      at: r.createdAt,
      roles: ['DIRECTOR', 'DUTY'],
      classIds: null,
      params: {},
      subject: null,
      href: null,
    }));
}
