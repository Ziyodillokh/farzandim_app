// Bola ovozi saqlangan bildirishnomalarining barqaror id'lari (upsert va tozalash uchun).
// `care:<id>` hisoblangan lentadagi id bilan bir xil — nishonlangan xodimda bittadan ko'rinadi.
// Direktorga boradigan signal id'si murojaat id'sini OCHMAYDI (direktor murojaatlarni ko'ra olmaydi):
// id — murojaat id'sining bir tomonlama xeshi.

import { createHash } from 'node:crypto';

export const urgentNotificationId = (requestId: string) => `care:${requestId}`;
export const escalationNotificationId = (requestId: string) => `care-esc:${requestId}`;
export const directorNotificationId = (requestId: string) =>
  `care-esc-dir:${createHash('sha256').update(`care-esc-dir:${requestId}`).digest('hex').slice(0, 32)}`;

export const careNotificationIds = (requestId: string): string[] => [
  urgentNotificationId(requestId),
  escalationNotificationId(requestId),
  directorNotificationId(requestId),
];
