import axios from 'axios';
import { getApiErrorMessage } from '@/lib/api/client';
import { getApiErrorCode } from '@/components/kelajak/kelajak-errors';

/** Maktablar API xatosi — o'zbekcha xabar (backend xabarlari ham o'zbekcha). */
export function schoolsErrorMessage(err: unknown): string {
  if (axios.isAxiosError(err) && err.response?.status === 403 && !getApiErrorCode(err)) {
    return "Bu bo'lim uchun ruxsat yo'q (Maktablar boshqaruvi).";
  }
  return getApiErrorMessage(err);
}

export { getApiErrorCode };
