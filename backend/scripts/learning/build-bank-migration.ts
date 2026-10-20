// Savollar banki JSON'laridan (prisma/data/learning-questions/<fan>.json)
// ma'lumot migratsiyasi SQL'ini yaratadi. Har savol `parseBankQuestion`
// bilan tekshiriladi (admin importi bilan bir xil qoida); id `externalId`dan
// deterministik — qayta yaratilganda SQL o'zgarmaydi.
//
//   npx tsx scripts/learning/build-bank-migration.ts > prisma/migrations/<nom>/migration.sql
//   npx tsx scripts/learning/build-bank-migration.ts 2 > prisma/migrations/<nom>/migration.sql  # 2-to'lqin

import { createHash } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { parseBankQuestion } from '../../src/modules/learning/domain/question-bank';
import { fromApiSubject } from '../../src/modules/learning/domain/subjects';

const DATA_DIR = path.resolve(__dirname, '../../prisma/data/learning-questions');

/** To'lqinlar: manba papkasi va migratsiya sarlavhasi (eski to'lqin chiqishi o'zgarmaydi). */
export const BANK_WAVES = {
  1: { dir: DATA_DIR, title: 'boshlang\'ich savollar banki (10 fan, uz/ru/en,' },
  2: { dir: `${DATA_DIR}-2`, title: '2-to\'lqin — 1–4 va 10–11-sinflar savollari (uz/ru/en,' },
} as const;

/** externalId → barqaror UUID (v5 shaklida, SHA-1). */
export function stableId(externalId: string): string {
  const hex = createHash('sha1').update(`parvoz-learning:${externalId}`).digest('hex');
  const variant = ((parseInt(hex[16], 16) & 0x3) | 0x8).toString(16);
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    `5${hex.slice(13, 16)}`,
    `${variant}${hex.slice(17, 20)}`,
    hex.slice(20, 32),
  ].join('-');
}

const literal = (value: unknown) => `'${JSON.stringify(value).replace(/'/g, "''")}'::jsonb`;

export function buildBankMigrationSql(dataDir: string = DATA_DIR, title: string = BANK_WAVES[1].title): string {
  const files = readdirSync(dataDir).filter((f) => f.endsWith('.json')).sort();
  const rows: string[] = [];
  for (const file of files) {
    const bank = JSON.parse(readFileSync(path.join(dataDir, file), 'utf8'));
    const subject = fromApiSubject(String(bank.subject));
    if (!subject) throw new Error(`${file}: noma'lum fan ${bank.subject}`);
    for (const [index, raw] of (bank.questions as unknown[]).entries()) {
      const parsed = parseBankQuestion(raw, subject);
      if (!parsed.ok) throw new Error(`${file}[${index}]: ${parsed.error}`);
      const q = parsed.value;
      if (!q.externalId) throw new Error(`${file}[${index}]: id yo'q`);
      rows.push(
        `('${stableId(q.externalId)}', '${q.externalId}', '${q.subject}', ${q.difficulty}, ` +
          `${q.minGrade}, ${q.maxGrade}, ${literal(q.topic)}, ${literal(q.prompt)}, ` +
          `${literal(q.options)}, ${q.answerIndex}, ${literal(q.explanation)}, ` +
          `'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)`,
      );
    }
  }
  return (
    [
      `-- Growth Daily Learning: ${title}`,
      '-- izohlar bilan). scripts/learning/build-bank-migration.ts yaratgan —',
      '-- qo\'lda tahrirlamang. Mavjud (externalId) savollar o\'zgartirilmaydi.',
      '',
      'INSERT INTO "learning_questions" ("id", "external_id", "subject", "difficulty",',
      '  "min_grade", "max_grade", "topic", "prompt", "options", "answer_index",',
      '  "explanation", "status", "created_at", "updated_at")',
      'VALUES',
      rows.join(',\n'),
      'ON CONFLICT ("external_id") DO NOTHING;',
      '',
    ].join('\n')
  );
}

if (require.main === module) {
  const wave = BANK_WAVES[process.argv[2] === '2' ? 2 : 1];
  process.stdout.write(buildBankMigrationSql(wave.dir, wave.title));
}
