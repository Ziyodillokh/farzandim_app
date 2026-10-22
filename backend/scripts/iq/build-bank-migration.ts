// IQ savollar banki JSON'laridan ma'lumot migratsiyalari SQL'ini yaratadi.
// Har savol `parseIqBank` bilan tekshiriladi; id `externalId`dan deterministik.
// Mavjud savollar o'zgartirilmaydi (ON CONFLICT DO NOTHING).
//
//   items.json      — rasmli savollar (generator.py), A/B formalar;
//   text_items.json — matnli savollar (text_items.py), C/D formalar;
//   mixed_forms.json — C/D formalarga kiradigan rasmli savollar.
//
//   npx tsx scripts/iq/build-bank-migration.ts > prisma/migrations/20261021180100_iq_item_bank/migration.sql
//   npx tsx scripts/iq/build-bank-migration.ts --mixed > prisma/migrations/20261022090100_iq_mixed_bank/migration.sql

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { IqFiguralItem, IqItemData, IqTextItem, MixedFormsMap, parseIqBank } from '../../src/modules/iq/domain/bank';
import { FORM_SIZE } from '../../src/modules/iq/domain/levels';

const DATA_DIR = path.resolve(__dirname, '../../prisma/data/iq');
export const IQ_BANK_FILE = path.join(DATA_DIR, 'items.json');
export const IQ_TEXT_FILE = path.join(DATA_DIR, 'text_items.json');
export const IQ_MIXED_FORMS_FILE = path.join(DATA_DIR, 'mixed_forms.json');

type Row<T extends IqItemData = IqItemData> = T & { id: string };

/** externalId → barqaror UUID (v5 shaklida, SHA-1, prefiks `parvoz-iq:`). */
export function stableIqId(externalId: string): string {
  const hex = createHash('sha1').update(`parvoz-iq:${externalId}`).digest('hex');
  const variant = ((parseInt(hex[16], 16) & 0x3) | 0x8).toString(16);
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    `5${hex.slice(13, 16)}`,
    `${variant}${hex.slice(17, 20)}`,
    hex.slice(20, 32),
  ].join('-');
}

const readJson = (file: string): unknown => JSON.parse(readFileSync(file, 'utf8'));

function parsedRows(raw: unknown[], mixed: MixedFormsMap = {}): Row[] {
  const { items, errors } = parseIqBank(raw, FORM_SIZE, mixed);
  if (errors.length > 0) throw new Error(`IQ banki:\n${errors.join('\n')}`);
  return items.map((it) => ({ ...it, id: stableIqId(it.externalId) }));
}

/** Faqat rasmli savollar, A/B formalar — birinchi migratsiya holati. */
export function buildFiguralRows(file: string = IQ_BANK_FILE): Array<Row<IqFiguralItem>> {
  return parsedRows(readJson(file) as unknown[]) as Array<Row<IqFiguralItem>>;
}

/** To'liq bank: rasmli + matnli savollar, A–D formalar (e2e seed va tekshiruv). */
export function buildIqBankRows(): Row[] {
  const raw = [...(readJson(IQ_BANK_FILE) as unknown[]), ...(readJson(IQ_TEXT_FILE) as unknown[])];
  return parsedRows(raw, readJson(IQ_MIXED_FORMS_FILE) as MixedFormsMap);
}

export function readMixedForms(): MixedFormsMap {
  return readJson(IQ_MIXED_FORMS_FILE) as MixedFormsMap;
}

const str = (value: string) => `'${value.replace(/'/g, "''")}'`;
const json = (value: unknown) => `${str(JSON.stringify(value))}::jsonb`;
const textArray = (values: string[]) =>
  values.length ? `ARRAY[${values.map(str).join(', ')}]::text[]` : `'{}'::text[]`;

function figuralRowSql(q: Row<IqFiguralItem>): string {
  return (
    `(${str(q.id)}, ${str(q.externalId)}, ${q.level}, ${textArray(q.forms)}, ${str(q.gridSvg)}, ` +
    `${json(q.options)}, ${str(q.answer)}, ${q.b}, ${str(q.rule)}, true, ` +
    'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)'
  );
}

function textRowSql(q: Row<IqTextItem>): string {
  return (
    `(${str(q.id)}, ${str(q.externalId)}, ${q.level}, ${str(q.kind)}::"IqItemKind", ${textArray(q.forms)}, ` +
    `${json(q.stem)}, ${json(q.options)}, ${str(q.answer)}, ${q.b}, ${str(q.rule)}, true, ` +
    'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)'
  );
}

export function buildIqBankMigrationSql(file: string = IQ_BANK_FILE): string {
  const rows = buildFiguralRows(file);
  return [
    `-- Parvoz IQ: rasmli matritsalar banki (${rows.length} savol, 5 daraja × A/B forma + zaxira).`,
    "-- scripts/iq/build-bank-migration.ts yaratgan — qo'lda tahrirlamang.",
    "-- Mavjud (external_id) savollar o'zgartirilmaydi.",
    '',
    'INSERT INTO "iq_items" ("id", "external_id", "level", "forms", "grid_svg", "options",',
    '  "answer", "b", "rule", "active", "created_at", "updated_at")',
    'VALUES',
    rows.map(figuralRowSql).join(',\n'),
    'ON CONFLICT ("external_id") DO NOTHING;',
    '',
  ].join('\n');
}

/** Aralash formalar: matnli savollar + rasmli savollarga C/D forma (takror ishga tushsa ham xavfsiz). */
export function buildIqMixedMigrationSql(): string {
  const text = buildIqBankRows().filter((r): r is Row<IqTextItem> => r.kind !== 'FIGURAL');
  const mixed = readMixedForms();
  const updates = Object.entries(mixed).map(
    ([form, ids]) =>
      `UPDATE "iq_items" SET "forms" = array_append("forms", ${str(form)}), "updated_at" = CURRENT_TIMESTAMP\n` +
      `WHERE "external_id" IN (${ids.map(str).join(', ')}) AND NOT (${str(form)} = ANY("forms"));`,
  );
  return [
    `-- Parvoz IQ: aralash formalar C/D (${text.length} matnli savol + ${Object.keys(mixed).length} formaga rasmli savollar).`,
    "-- scripts/iq/build-bank-migration.ts --mixed yaratgan — qo'lda tahrirlamang.",
    "-- Mavjud (external_id) savollar o'zgartirilmaydi; A/B formalar o'zgarmaydi.",
    '',
    'INSERT INTO "iq_items" ("id", "external_id", "level", "kind", "forms", "stem", "options",',
    '  "answer", "b", "rule", "active", "created_at", "updated_at")',
    'VALUES',
    text.map(textRowSql).join(',\n'),
    'ON CONFLICT ("external_id") DO NOTHING;',
    '',
    ...updates,
    '',
  ].join('\n');
}

if (require.main === module) {
  process.stdout.write(process.argv.includes('--mixed') ? buildIqMixedMigrationSql() : buildIqBankMigrationSql());
}
