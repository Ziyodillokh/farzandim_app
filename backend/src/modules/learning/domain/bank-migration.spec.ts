// Savollar banki ma'lumot migratsiyasi JSON manbadan yaratilgan va qo'lda
// o'zgartirilmagan (JSON tahrirlansa — skript qayta ishga tushirilishi
// kerak, mavjud savollar esa admin importi orqali yangilanadi).

import { readFileSync } from 'node:fs';
import path from 'node:path';
import { buildBankMigrationSql } from '../../../../scripts/learning/build-bank-migration';

describe('learning question bank migration', () => {
  it('JSON manbadan qayta yaratilganda fayl bilan bir xil', () => {
    const file = path.resolve(
      __dirname,
      '../../../../prisma/migrations/20261019200200_learning_question_bank/migration.sql',
    );
    const sql = buildBankMigrationSql();
    expect(readFileSync(file, 'utf8')).toBe(sql);
    expect(sql.match(/^\('/gm)).toHaveLength(174);
  });
});
