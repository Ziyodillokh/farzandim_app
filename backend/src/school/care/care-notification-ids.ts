// Bola ovozi saqlangan bildirishnomalarining barqaror id'lari (upsert va tozalash uchun).
// Hisoblangan lentadagi `care:<id>` bilan bir xil — nishonlangan xodimda bittadan ko'rinadi.

export const urgentNotificationId = (requestId: string) => `care:${requestId}`;
export const escalationNotificationId = (requestId: string) => `care-esc:${requestId}`;
export const directorNotificationId = (requestId: string) => `care-esc-dir:${requestId}`;

export const careNotificationIds = (requestId: string): string[] => [
  urgentNotificationId(requestId),
  escalationNotificationId(requestId),
  directorNotificationId(requestId),
];
