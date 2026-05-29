import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

/**
 * Combine class names with Tailwind merge.
 * Used by shadcn/ui components and custom widgets.
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/**
 * Format UZS currency.
 *   formatUzs(35000) -> "35 000 so'm"
 */
export function formatUzs(value: number): string {
  return new Intl.NumberFormat('uz-UZ').format(value) + " so'm";
}

/**
 * Format duration in milliseconds to human-readable.
 *   formatDuration(3600000) -> "1 soat"
 */
export function formatDuration(ms: number): string {
  const seconds = Math.floor(ms / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);

  if (hours > 0) return `${hours} soat ${minutes % 60} daq`;
  if (minutes > 0) return `${minutes} daq`;
  return `${seconds} son`;
}
