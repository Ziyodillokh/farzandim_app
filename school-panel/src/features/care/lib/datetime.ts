import { toLocalIso } from '@/data/mock/calendar';

const HAS_ZONE = /(?:[zZ]|[+-]\d{2}:?\d{2})$/;

/**
 * Saqlangan vaqt → `datetime-local` qiymati ("YYYY-MM-DDTHH:MM", brauzer mahalliy vaqti).
 * Demo mahalliy vaqt beradi (zonasiz) — kesiladi; backend UTC ISO (`…Z`) beradi — mahalliy vaqtga o'giriladi
 * (aks holda UTC soati mahalliy deb ko'rsatilib, har saqlashda siljib ketardi).
 */
export function toLocalInput(value: string | null): string {
  if (!value) return '';
  return (HAS_ZONE.test(value) ? toLocalIso(new Date(value)) : value).slice(0, 16);
}
