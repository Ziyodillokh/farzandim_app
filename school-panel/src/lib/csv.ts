/**
 * CSV eksport — Excel (O'zbekiston/Rossiya lokali) to'g'ri ochishi uchun:
 * UTF-8 BOM, `;` ajratuvchi, CRLF. Formula-injection himoyasi: `= + - @`
 * bilan boshlanadigan qiymat oldiga `'` qo'yiladi.
 */
export type CsvColumn<T> = { header: string; value: (row: T) => string | number | null | undefined };

const FORMULA_START = /^[=+\-@\t\r]/;

export function escapeCsvCell(raw: string | number | null | undefined): string {
  if (raw === null || raw === undefined) return '';
  let value = String(raw);
  if (FORMULA_START.test(value)) value = `'${value}`;
  if (/[";\r\n]/.test(value)) value = `"${value.replace(/"/g, '""')}"`;
  return value;
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
