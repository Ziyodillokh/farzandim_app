/**
 * CSV eksport — Excel (O'zbekiston/Rossiya lokali) to'g'ri ochishi uchun:
 * UTF-8 BOM, `;` ajratuvchi, CRLF. Formula-injection himoyasi: `= + - @`
 * bilan boshlanadigan qiymat oldiga `'` qo'yiladi — oddiy son (`-0,3`) bundan
 * mustasno, aks holda Excel uni matn deb o'qiydi.
 */
import type { MetricKey } from '@/data/contracts';
import { METRICS } from '@/data/mock/model/metrics';

export type CsvColumn<T> = { header: string; value: (row: T) => string | number | null | undefined };

const FORMULA_START = /^[=+\-@\t\r]/;
const PLAIN_NUMBER = /^-?\d+([.,]\d+)?$/;

export function escapeCsvCell(raw: string | number | null | undefined): string {
  if (raw === null || raw === undefined) return '';
  let value = String(raw);
  if (FORMULA_START.test(value) && !PLAIN_NUMBER.test(value)) value = `'${value}`;
  if (/[";\r\n]/.test(value)) value = `"${value.replace(/"/g, '""')}"`;
  return value;
}

/**
 * Excel (uz/ru lokali) uchun son: o'nlik vergul, minglik ajratuvchisiz, oddiy "-"
 * (formula himoyasi sof sonni o'tkazadi — Excel uni son deb o'qiydi); yo'q qiymat — bo'sh katak.
 * `decimals` berilsa — aynan shuncha kasr xonasi.
 */
export function csvNumber(v: number | null | undefined, decimals?: number): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return '';
  return (decimals === undefined ? String(v) : v.toFixed(decimals)).replace('.', ',');
}

/** `csvNumber` ning `null` qaytaradigan ko'rinishi (CsvColumn qiymati uchun). */
export function csvDecimal(v: number | null | undefined, decimals = 1): string | null {
  const text = csvNumber(v, decimals);
  return text === '' ? null : text;
}

/** Fayl nomi uchun mahalliy sana: 2026-10-30. */
export function csvDateStamp(now: Date = new Date()): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

/** Ustun sarlavhasi birlik bilan: "Bulling signali, %", "Ekran vaqti, daq". */
export function csvMetricHeader(metric: MetricKey, label: string, minuteUnit: string): string {
  const unit = METRICS[metric].unit;
  if (unit === '%') return `${label}, %`;
  if (unit === 'min') return `${label}, ${minuteUnit}`;
  return label;
}

export function toCsv<T>(rows: readonly T[], columns: readonly CsvColumn<T>[]): string {
  const header = columns.map((c) => escapeCsvCell(c.header)).join(';');
  const body = rows.map((row) => columns.map((c) => escapeCsvCell(c.value(row))).join(';'));
  return `﻿${[header, ...body].join('\r\n')}`;
}

export function downloadCsv<T>(filename: string, rows: readonly T[], columns: readonly CsvColumn<T>[]): void {
  const blob = new Blob([toCsv(rows, columns)], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename.endsWith('.csv') ? filename : `${filename}.csv`;
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** Oddiy CSV o'qish (`;` yoki `,`, qo'shtirnoqli maydonlar). Import uchun. */
export function parseCsv(text: string): string[][] {
  const clean = text.replace(/^﻿/, '');
  const firstLine = clean.split(/\r?\n/, 1)[0] ?? '';
  const delimiter = (firstLine.match(/;/g)?.length ?? 0) >= (firstLine.match(/,/g)?.length ?? 0) ? ';' : ',';
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let inQuotes = false;
  for (let i = 0; i < clean.length; i++) {
    const ch = clean[i];
    if (inQuotes) {
      if (ch === '"' && clean[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (ch === '"') {
        inQuotes = false;
      } else {
        cell += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === delimiter) {
      row.push(cell);
      cell = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && clean[i + 1] === '\n') i++;
      row.push(cell);
      if (row.some((c) => c.trim() !== '')) rows.push(row);
      row = [];
      cell = '';
    } else {
      cell += ch;
    }
  }
  row.push(cell);
  if (row.some((c) => c.trim() !== '')) rows.push(row);
  return rows;
}
