import axios from 'axios';
import { getApiErrorMessage } from '@/lib/api/client';

export const KEY_CONFLICT_MESSAGE = 'Bu kalit shu fanda allaqachon bor';

/** `POST/PATCH /admin/learning/topics` — kalit shu fanda band (409). */
export function isKeyConflict(err: unknown): boolean {
  return axios.isAxiosError(err) && err.response?.status === 409;
}

/** Mavzular API xatosini o'zbekcha xabarga aylantiradi. */
export function topicErrorMessage(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const status = err.response?.status;
    if (status === 403) return "Bu bo'lim uchun ruxsat yo'q: moderator ruxsatlarida \"Savollar banki\" kerak.";
    if (status === 404) return 'Mavzu topilmadi — sahifani yangilang.';
  }
  return getApiErrorMessage(err);
}
