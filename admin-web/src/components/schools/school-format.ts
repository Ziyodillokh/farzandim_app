import type { SchoolStaffRole } from '@/types/api.types';

const MONTHS = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];

/** «11-noy 2026» (Toshkent vaqti). */
export function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Tashkent',
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
  })
    .formatToParts(d)
    .reduce<Record<string, string>>((acc, p) => ({ ...acc, [p.type]: p.value }), {});
  return `${Number(parts.day)}-${MONTHS[Number(parts.month) - 1]} ${parts.year}`;
}

export const ROLE_LABEL: Record<SchoolStaffRole, string> = {
  DIRECTOR: 'Direktor',
  ADMIN: "Ma'muriyat",
  HOMEROOM: 'Sinf rahbari',
  PSYCHOLOGIST: 'Psixolog',
  DUTY: 'Navbatchi',
  TEACHER: "O'qituvchi",
};
