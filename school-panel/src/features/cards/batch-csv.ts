import type { CardImportRow, CardReservation } from '@/data/contracts';
import { normalizeReaderUid } from '@/data/schemas/cards';
import { formatCardNumber } from '@/lib/card-number';
import type { CsvColumn } from '@/lib/csv';

/**
 * Karta partiyasi fayllari: bosmaxona ro'yxati (eksport) va ta'minotchi fayli (raqam ↔ UID, import).
 */

type Translate = (key: 'cards.batch.csv.number' | 'cards.batch.csv.barcode' | 'cards.batch.csv.student' | 'cards.batch.csv.className' | 'cards.batch.csv.code') => string;

/** Bosmaxona ro'yxati: kartaga bosiladigan raqam (5+5), shtrix-kod uchun yaxlit raqam, ism, sinf. */
export function printColumns(t: Translate): CsvColumn<CardReservation>[] {
  return [
    { header: t('cards.batch.csv.number'), value: (r) => formatCardNumber(r.number) },
    { header: t('cards.batch.csv.barcode'), value: (r) => r.number },
    { header: t('cards.batch.csv.student'), value: (r) => r.studentName },
    { header: t('cards.batch.csv.className'), value: (r) => r.className },
    { header: t('cards.batch.csv.code'), value: (r) => r.studentCode },
  ];
}

const NUMBER_HEADER = /raqam|number|номер|karta|card/i;
const UID_HEADER = /uid|serial|chip|чип/i;

/**
 * Ta'minotchi fayli → qatorlar. Sarlavha bo'lsa ustunlar nomidan topiladi (raqam / UID), aks holda
 * 1-ustun — raqam, 2-ustun — UID. UID o'nlik bo'lsa hex'ga o'giriladi; bo'sh qatorlar tashlanadi.
 */
export function importRowsFromCsv(cells: readonly (readonly string[])[]): CardImportRow[] {
  const rows = cells.filter((r) => r.some((c) => c.trim()));
  if (rows.length === 0) return [];
  const header = rows[0];
  const uidIdx = header.findIndex((h) => UID_HEADER.test(h));
  const numberIdx = header.findIndex((h, i) => i !== uidIdx && NUMBER_HEADER.test(h));
  const named = uidIdx >= 0 && numberIdx >= 0;
  const headerless = !named && !/\d/.test(header[0] ?? '');
  const body = named || headerless ? rows.slice(1) : rows;
  const [ni, ui] = named ? [numberIdx, uidIdx] : [0, 1];
  return body
    .map((r) => {
      const rawUid = (r[ui] ?? '').trim();
      return { number: (r[ni] ?? '').replace(/\s/g, ''), uid: normalizeReaderUid(rawUid) ?? rawUid };
    })
    .filter((r) => r.number || r.uid);
}
