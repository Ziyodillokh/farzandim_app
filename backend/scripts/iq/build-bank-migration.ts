// IQ savollar banki JSON'idan (prisma/data/iq/items.json — generator.py)
// ma'lumot migratsiyasi SQL'ini yaratadi. Har savol `parseIqBank` bilan
// tekshiriladi; id `externalId`dan deterministik. Mavjud savollar
// o'zgartirilmaydi (ON CONFLICT DO NOTHING).
//
//   npx tsx scripts/iq/build-bank-migration.ts > prisma/migrations/20261021180100_iq_item_bank/migration.sql

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { IqItemData, parseIqBank } from '../../src/modules/iq/domain/bank';
import { FORM_SIZE } from '../../src/modules/iq/domain/levels';

export const IQ_BANK_FILE = path.resolve(__dirname, '../../prisma/data/iq/items.json');

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

export function buildIqBankRows(file: string = IQ_BANK_FILE): Array<IqItemData & { id: string }> {
  const { items, errors } = parseIqBank(JSON.parse(readFileSync(file, 'utf8')), FORM_SIZE);
  if (errors.length > 0) throw new Error(`IQ banki:\n${errors.join('\n')}`);
  return items.map((it) => ({ ...it, id: stableIqId(it.externalId) }));
}

const str = (value: string) => `'${value.replace(/'/g, "''")}'`;
const textArray = (values: string[]) =>
  values.length ? `ARRAY[${values.map(str).join(', ')}]::text[]` : `'{}'::text[]`;

function rowSql(q: IqItemData & { id: string }): string {
  return (
    `(${str(q.id)}, ${str(q.externalId)}, ${q.level}, ${textArray(q.forms)}, ${str(q.gridSvg)}, ` +
    `${str(JSON.stringify(q.options))}::jsonb, ${str(q.answer)}, ${q.b}, ${str(q.rule)}, true, ` +
    'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)'
  );
}

export function buildIqBankMigrationSql(file: string = IQ_BANK_FILE): string {
  const rows = buildIqBankRows(file);
  return [
    `-- Parvoz IQ: rasmli matritsalar banki (${rows.length} savol, 5 daraja × A/B forma + zaxira).`,
    "-- scripts/iq/build-bank-migration.ts yaratgan — qo'lda tahrirlamang.",
    "-- Mavjud (external_id) savollar o'zgartirilmaydi.",
    '',
    'INSERT INTO "iq_items" ("id", "external_id", "level", "forms", "grid_svg", "options",',
    '  "answer", "b", "rule", "active", "created_at", "updated_at")',
    'VALUES',
    rows.map(rowSql).join(',\n'),
    'ON CONFLICT ("external_id") DO NOTHING;',
    '',
  ].join('\n');
}

if (require.main === module) {
  process.stdout.write(buildIqBankMigrationSql());
}
