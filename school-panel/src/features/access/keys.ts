import type { QueryClient } from '@tanstack/react-query';

import type { CredentialsView } from '@/data/contracts';

export const accessKeys = {
  all: ['access'] as const,
  credentials: (studentId: string) => ['access', 'credentials', studentId] as const,
  recovery: (studentId: string) => ['access', 'recovery', studentId] as const,
  inviteCode: (studentId: string) => ['access', 'invite-code', studentId] as const,
};

/**
 * Backend `NOT_LINKED` desa karta «ulanmagan» holatiga o'tadi. Faqat keshni yangilash yetarli emas bo'lishi mumkin: o'quvchi
 * ulanmagan bo'lsa GET `409` o'rniga `null` qaytarishi mumkin — shunda qayta so'rov «ulangan, berilmagan» ko'rsatardi.
 */
export function markNotLinked(client: QueryClient, studentId: string): void {
  client.setQueryData<CredentialsView>(accessKeys.credentials(studentId), { linked: false, credentials: null });
}
