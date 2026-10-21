// Parvoz Kelajak savollar banki JSON'idan (prisma/data/kelajak/) ma'lumot
// migratsiyasi SQL'ini yaratadi. Har savol `parseKelajakBank` bilan
// tekshiriladi (import CLI va admin bilan bir xil qoida); `active`, `reverse`,
// `review_note` va scoring teglari — ko'rib chiqish qarorlarining MUZLATILGAN
// nusxasidan (review-overrides.20261021090100.json), `required` — javob turi
// qoidasidan. id `externalId`dan deterministik — qayta yaratilganda SQL
// o'zgarmaydi (docs/KELAJAK-REJA.md §2). Qo'llangan migratsiya qayta
// yozilmaydi: keyingi qarorlar review-overrides.json + import CLI (--update).
//
//   npx tsx scripts/kelajak/build-bank-migration.ts > prisma/migrations/20261021090100_kelajak_question_bank/migration.sql

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import {
  KelajakQuestionData,
  parseKelajakBank,
  parseReviewOverrides,
  ReviewOverrides,
} from '../../src/modules/kelajak/domain/bank';

const DATA_DIR = path.resolve(__dirname, '../../prisma/data/kelajak');
export const KELAJAK_BANK_FILE = path.join(DATA_DIR, 'parvoz_question_bank_278.json');
/** Joriy ko'rib chiqish qarorlari — import CLI standarti (tahrirlanadi). */
export const KELAJAK_OVERRIDES_FILE = path.join(DATA_DIR, 'review-overrides.json');
/** Migratsiya yaratilgan qarorlar nusxasi — O'ZGARTIRILMAYDI (spec sha256'ni tekshiradi). */
export const KELAJAK_MIGRATION_OVERRIDES_FILE = path.join(DATA_DIR, 'review-overrides.20261021090100.json');

/** externalId → barqaror UUID (v5 shaklida, SHA-1, prefiks `parvoz-kelajak:`). */
export function stableKelajakId(externalId: string): string {
  const hex = createHash('sha1').update(`parvoz-kelajak:${externalId}`).digest('hex');
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

export function loadKelajakOverrides(file: string = KELAJAK_OVERRIDES_FILE): ReviewOverrides {
  const parsed = parseReviewOverrides(readJson(file));
  if (!parsed.ok) throw new Error(`${path.basename(file)}: ${parsed.error}`);
  return parsed.value;
}

export type KelajakBankRow = KelajakQuestionData & { id: string; externalId: string };

/** Bank qatorlari; bitta xato, dublikat yoki id'siz savol bo'lsa — `Error`. */
export function buildKelajakBankRows(
  bankFile: string = KELAJAK_BANK_FILE,
  overridesFile: string = KELAJAK_MIGRATION_OVERRIDES_FILE,
): KelajakBankRow[] {
  const parsed = parseKelajakBank(readJson(bankFile), loadKelajakOverrides(overridesFile));
  const problems = [
    ...parsed.invalid.map((e) => `[${e.index}] ${e.externalId ?? '?'}: ${e.error}`),
    ...parsed.duplicates.map((d) => `${d.externalId}: dublikat`),
    ...parsed.warnings,
  ];
  if (problems.length > 0) throw new Error(`Kelajak banki:\n${problems.join('\n')}`);
  return parsed.valid.map((q, index) => {
    if (!q.externalId) throw new Error(`[${index}]: id yo'q`);
    return { ...q, id: stableKelajakId(q.externalId), externalId: q.externalId };
  });
}

const str = (value: string | null) => (value === null ? 'NULL' : `'${value.replace(/'/g, "''")}'`);
const json = (value: unknown) =>
  value === null ? 'NULL' : `'${JSON.stringify(value).replace(/'/g, "''")}'::jsonb`;

function rowSql(q: KelajakBankRow): string {
  return (
    `(${str(q.id)}, ${str(q.externalId)}, ${str(q.category)}, ${str(q.ageGroup)}, ` +
    `${json(q.text)}, ${str(q.answerType)}, ${json(q.options)}, ${json(q.scoring)}, ` +
    `${q.reverse}, ${q.required}, ${str(q.followUp)}, ${str(q.notes)}, ${str(q.reviewNote)}, ` +
    `${str(q.sourceType)}, ${str(q.sourceName)}, ${str(q.sourceVersion)}, ${q.active}, ` +
    'CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)'
  );
}

export function buildKelajakBankMigrationSql(
  bankFile: string = KELAJAK_BANK_FILE,
  overridesFile: string = KELAJAK_MIGRATION_OVERRIDES_FILE,
): string {
  const rows = buildKelajakBankRows(bankFile, overridesFile);
  return (
    [
      `-- Parvoz Kelajak: savollar banki (${rows.length} savol, faqat uz).`,
      '-- scripts/kelajak/build-bank-migration.ts yaratgan — qo\'lda tahrirlamang.',
      '-- active / reverse / review_note / scoring teglari — prisma/data/kelajak/',
      '-- review-overrides.20261021090100.json (muzlatilgan), required — javob turi',
      '-- qoidasi. Mavjud (externalId) savollar o\'zgartirilmaydi.',
      '',
      'INSERT INTO "kelajak_questions" ("id", "external_id", "category", "age_group",',
      '  "text", "answer_type", "options", "scoring", "reverse", "required",',
      '  "follow_up", "notes", "review_note", "source_type", "source_name",',
      '  "source_version", "active", "created_at", "updated_at")',
      'VALUES',
      rows.map(rowSql).join(',\n'),
      'ON CONFLICT ("external_id") DO NOTHING;',
      '',
    ].join('\n')
  );
}

if (require.main === module) {
  process.stdout.write(buildKelajakBankMigrationSql());
}
