import type { MetricKey } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';

/**
 * Excel (uz/ru lokali) uchun son: vergulli kasr, guruhlashsiz; bo'sh qiymat — bo'sh katak.
 * Oddiy "-" ishlatiladi: `lib/csv` sof sonlarni formula deb hisoblamaydi, Excel ularni son sifatida o'qiydi.
 */
export function csvNumber(v: number | null | undefined): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return '';
  return String(v).replace('.', ',');
}

/** Fayl nomi uchun mahalliy sana: 2026-10-30. */
export function csvStamp(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** CSV sarlavhasi birlik bilan: "O'zlashtirish, %", "Ekran vaqti, daq". */
export function csvMetricHeader(metric: MetricKey, label: string, minuteUnit: string): string {
  const unit = METRICS[metric].unit;
  if (unit === '%') return `${label}, %`;
  if (unit === 'min') return `${label}, ${minuteUnit}`;
  return label;
}
