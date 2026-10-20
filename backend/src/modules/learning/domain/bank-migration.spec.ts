// Savollar banki ma'lumot migratsiyalari JSON manbadan yaratilgan va qo'lda
// o'zgartirilmagan (JSON tahrirlansa — skript qayta ishga tushirilishi
// kerak, mavjud savollar esa admin importi orqali yangilanadi).

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { BANK_WAVES, buildBankMigrationSql } from '../../../../scripts/learning/build-bank-migration';

const migration = (name: string) =>
  readFileSync(path.resolve(__dirname, `../../../../prisma/migrations/${name}/migration.sql`), 'utf8');

describe('learning question bank migrations', () => {
  it.each([
    [1, '20261019200200_learning_question_bank', 174],
    [2, '20261020170000_learning_question_bank_2', 156],
  ] as const)('%i-to\'lqin: JSON manbadan qayta yaratilganda fayl bilan bir xil', (wave, name, rows) => {
    const sql = buildBankMigrationSql(BANK_WAVES[wave].dir, BANK_WAVES[wave].title);
    expect(migration(name)).toBe(sql);
    expect(sql.match(/^\('/gm)).toHaveLength(rows);
  });

  it('to\'lqinlar orasida savol id\'lari takrorlanmaydi', () => {
    const ids = [1, 2].flatMap((wave) => {
      const sql = buildBankMigrationSql(BANK_WAVES[wave as 1 | 2].dir, BANK_WAVES[wave as 1 | 2].title);
      return [...sql.matchAll(/^\('([0-9a-f-]{36})', '([^']+)'/gm)].map((m) => m[2]);
    });
    expect(new Set(ids).size).toBe(ids.length);
  });
});
