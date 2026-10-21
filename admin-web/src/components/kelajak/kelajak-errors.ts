import axios from 'axios';
import { getApiErrorMessage } from '@/lib/api/client';
import { LOCKED_FIELD_LABELS } from '@/lib/constants/kelajak';

/** Backend xato kodi (`{ statusCode, message, code }`), bo'lmasa `undefined`. */
export function getApiErrorCode(err: unknown): string | undefined {
  if (!axios.isAxiosError(err)) return undefined;
  const data = err.response?.data as { code?: unknown } | undefined;
  return typeof data?.code === 'string' ? data.code : undefined;
}

const CODE_MESSAGES: Record<string, string> = {
  DUPLICATE_EXTERNAL_ID:
    "Bu ID bilan savol allaqachon bor. Boshqa ID kiriting yoki maydonni bo'sh qoldiring.",
  QUESTION_IN_USE: `Savolga javob berilgan yoki u bugungi ochiq sessiyada: ${LOCKED_FIELD_LABELS.join(', ')} o'zgarmaydi. Kerak bo'lsa savolni nofaol qilib, yangisini qo'shing.`,
};

/** Kelajak API xatosini o'zbekcha xabarga aylantiradi. */
export function kelajakErrorMessage(err: unknown): string {
  const code = getApiErrorCode(err);
  if (code && CODE_MESSAGES[code]) return CODE_MESSAGES[code];
  if (axios.isAxiosError(err)) {
    const status = err.response?.status;
    if (status === 403) return "Bu bo'lim uchun ruxsat yo'q (Growth va Kelajak savollari).";
    if (status === 404) return 'Savol topilmadi.';
  }
  return getApiErrorMessage(err);
}
