import { ServiceError } from '@/data/contracts';
import type { TKey } from '@/i18n';
import { hasKey } from '@/i18n/translate';

/**
 * Forma xatosi kaliti (`errors.form.*`). Backend panelda tarjimasi yo'q kalit yuborsa (yangi tekshiruv) —
 * xom kalit ko'rsatilmaydi, umumiy «ma'lumotlar noto'g'ri» xabari chiqadi.
 */
export function formErrorKey(key: string): TKey {
  return key.startsWith('errors.form.') && hasKey('uz', key) ? (key as TKey) : 'errors.VALIDATION';
}

/** Servis xatosini foydalanuvchiga ko'rsatiladigan tarjima kalitiga aylantirish. */
export function errorKey(error: unknown): TKey {
  if (error instanceof ServiceError) {
    const formKey = error.message.split(': ')[1];
    if (error.code === 'VALIDATION' && formKey?.startsWith('errors.form.')) return formErrorKey(formKey);
    return `errors.${error.code}` as TKey;
  }
  return 'errors.UNKNOWN';
}
