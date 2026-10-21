// Kelajak banki ma'lumot migratsiyasi JSON manbadan yaratilgan va qo'lda
// o'zgartirilmagan. Kirishlar MUZLATILGAN: bank JSON'i va ko'rib chiqish
// qarorlarining migratsiya nusxasi (review-overrides.20261021090100.json) —
// sha256 bilan. Qo'llangan migratsiya qayta yozilmaydi: keyingi qarorlar
// review-overrides.json'ga yoziladi va import CLI (--update) / admin orqali
// bazaga yetadi.

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import {
  buildKelajakBankMigrationSql,
  buildKelajakBankRows,
  KELAJAK_BANK_FILE,
  KELAJAK_MIGRATION_OVERRIDES_FILE,
  stableKelajakId,
} from '../../../../scripts/kelajak/build-bank-migration';

const FROZEN_INPUTS: ReadonlyArray<[string, string]> = [
  [KELAJAK_BANK_FILE, '1359fc1d2c4400716467742d795b54e5586d78dee51dec78ec2a4afae27d06e1'],
  [KELAJAK_MIGRATION_OVERRIDES_FILE, '0ca8d89498a574808c956ff880a37d09dd52a137995c1b384b15182ef1650e21'],
];
const sha256 = (file: string) => createHash('sha256').update(readFileSync(file)).digest('hex');

const MIGRATION = path.resolve(
  __dirname,
  '../../../../prisma/migrations/20261021090100_kelajak_question_bank/migration.sql',
);

describe('kelajak question bank migration', () => {
  const sql = buildKelajakBankMigrationSql();
  const rows = buildKelajakBankRows();

  it.each(FROZEN_INPUTS)('migratsiya kirishi o\'zgarmagan: %s', (file, expected) => {
    expect(sha256(file)).toBe(expected);
  });

  it('muzlatilgan kirishlardan qayta yaratilganda fayl bilan baytma-bayt bir xil', () => {
    expect(readFileSync(MIGRATION, 'utf8')).toBe(sql);
  });

  it('278 qator, 8 nofaol, 7 teskari; ON CONFLICT ("external_id") DO NOTHING', () => {
    expect(sql.match(/^\('/gm)).toHaveLength(278);
    expect(rows).toHaveLength(278);
    expect(rows.filter((r) => !r.active)).toHaveLength(8);
    expect(rows.filter((r) => r.reverse)).toHaveLength(7);
    expect(sql).toMatch(/ON CONFLICT \("external_id"\) DO NOTHING;\n$/);
  });

  it('id externalId\'dan deterministik (UUIDv5 shakli), takrorlanmaydi', () => {
    const id = stableKelajakId('PARVOZ-Q001');
    expect(id).toBe(stableKelajakId('PARVOZ-Q001'));
    expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(stableKelajakId('PARVOZ-Q002')).not.toBe(id);
    expect(new Set(rows.map((r) => r.id)).size).toBe(278);
    expect(sql).toContain(`('${id}', 'PARVOZ-Q001', 'career_interest', '7-9'`);
  });

  it('matn {uz} JSON, text savolida scoring NULL va required=false', () => {
    const line = sql.split('\n').find((l) => l.includes("'PARVOZ-Q247'"))!;
    expect(line).toContain(`'{"uz":"Maktabda seni eng ko‘p xursand qiladigan narsa nima?"}'::jsonb, 'text', '[]'::jsonb, NULL, false, false,`);
  });
});
