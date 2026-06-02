import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

/** Tailwind class names'ni merge qiladi (shadcn/ui standart helper). */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** UZS formatlash: `formatUzs(35000)` → `"35 000 so'm"`. */
export function formatUzs(value: number | null | undefined): string {
  if (value == null) return '—';
  return new Intl.NumberFormat('uz-UZ').format(value) + " so'm";
}

/** Raqamlarni qisqartirish: 1234 → "1.2K", 1,250,000 → "1.25M". */
export function formatCompact(value: number | null | undefined): string {
  if (value == null) return '—';
  return new Intl.NumberFormat('uz-UZ', { notation: 'compact', maximumFractionDigits: 1 }).format(value);
}

/** ms → "1 soat 23 daq" yoki "5 daq". */
export function formatDuration(ms: number): string {
  const minutes = Math.floor(ms / 60000);
  const hours = Math.floor(minutes / 60);
  if (hours > 0) return `${hours} soat ${minutes % 60} daq`;
  return `${minutes} daq`;
}

/** ISO sanani "x daqiqa/soat/kun oldin" formatda. */
export function formatRelative(iso: string | null | undefined): string {
  if (!iso) return '—';
  const t = new Date(iso).getTime();
  if (isNaN(t)) return '—';
  const diff = Date.now() - t;
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return 'hozirgina';
  if (minutes < 60) return `${minutes} daqiqa oldin`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} soat oldin`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days} kun oldin`;
  const months = Math.floor(days / 30);
  return months < 12 ? `${months} oy oldin` : `${Math.floor(months / 12)} yil oldin`;
}

/** Ism familyadan inisiyallar: "Aliyev Test" → "AT", "Asilbek" → "A". */
export function initials(name: string | null | undefined): string {
  if (!name) return '?';
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0][0]!.toUpperCase();
  return (parts[0][0]! + parts[1][0]!).toUpperCase();
}

/** Telefon raqamini ozsuvchan formatlash: "+998 90 123 45 67". */
export function formatPhone(phone: string | null | undefined): string {
  if (!phone) return '—';
  const digits = phone.replace(/\D/g, '');
  if (digits.length === 12 && digits.startsWith('998')) {
    return `+${digits.slice(0, 3)} ${digits.slice(3, 5)} ${digits.slice(5, 8)} ${digits.slice(8, 10)} ${digits.slice(10)}`;
  }
  return phone;
}

/** Delay helper (testlar uchun). */
export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
