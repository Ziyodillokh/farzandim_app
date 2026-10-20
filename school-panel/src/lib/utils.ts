import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

/** Tailwind class'larini birlashtiradi (shadcn/ui standarti). */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** "Karimova Dilnoza" → "KD". */
export function initials(name: string | null | undefined): string {
  if (!name) return '?';
  const parts = name.trim().split(/\s+/).filter(Boolean);
  const letters = parts.slice(0, 2).map((p) => p[0]?.toUpperCase() ?? '');
  return letters.join('') || '?';
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Foiz (0..100), maxraj 0 bo'lsa 0. */
export function percent(part: number, total: number): number {
  if (total <= 0) return 0;
  return Math.round((part / total) * 100);
}

/** Ulush foizi, 100 dan oshmaydi: masalan, o'tgan hafta faollari bugungi sinf tarkibidan ko'p bo'lishi mumkin. */
export function sharePercent(part: number, total: number): number {
  return Math.min(100, percent(part, total));
}

export function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

/** `"08:30"` → 510 (kun boshidan daqiqa). Noto'g'ri bo'lsa NaN. */
export function hhmmToMinutes(value: string): number {
  const match = /^(\d{2}):(\d{2})$/.exec(value);
  if (!match) return Number.NaN;
  return Number(match[1]) * 60 + Number(match[2]);
}

/** 510 → `"08:30"`. */
export function minutesToHhmm(total: number): string {
  const safe = ((Math.round(total) % 1440) + 1440) % 1440;
  const h = Math.floor(safe / 60);
  const m = safe % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}
