import { ServiceError } from '@/data/contracts';
import type { TKey } from '@/i18n';

/** Servis xatosini foydalanuvchiga ko'rsatiladigan tarjima kalitiga aylantirish. */
export function errorKey(error: unknown): TKey {
  if (error instanceof ServiceError) {
    const formKey = error.message.split(': ')[1];
    if (error.code === 'VALIDATION' && formKey?.startsWith('errors.form.')) return formKey as TKey;
    return `errors.${error.code}` as TKey;
  }
  return 'errors.UNKNOWN';
}
