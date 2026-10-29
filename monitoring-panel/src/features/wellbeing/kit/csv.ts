import type { MetricKey } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';

/** UI bilan bir xil minus: `lib/csv` formula himoyasi "-" yoki "+" bilan boshlangan qiymat oldiga "'" qo'yadi. */
const MINUS = '−';

/** Excel (uz/ru lokali) uchun son: vergulli kasr, guruhlashsiz; bo'sh qiymat — bo'sh katak. */
export function csvNumber(v: number | null | undefined): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return '';
  const text = String(Math.abs(v)).replace('.', ',');
  return v < 0 ? `${MINUS}${text}` : text;
}

/** Fayl nomi uchun mahalliy sana: 2026-10-30. */
export function csvStamp(now: Date = new Date()): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

/** Sarlavha birlik bilan: "Bulling signali, %", "Ekran vaqti, daq". */
export function csvHeader(metric: MetricKey, label: string, minuteUnit: string): string {
  const unit = METRICS[metric].unit;
  if (unit === '%') return `${label}, %`;
  if (unit === 'min') return `${label}, ${minuteUnit}`;
  return label;
}
