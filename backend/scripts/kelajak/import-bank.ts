// Kelajak savollar bankini import qilish (qayta ishga tushirish mumkin):
//
//   npx tsx scripts/kelajak/import-bank.ts <fayl.json> [--update] [--dry-run]
//     [--overrides <fayl>] [--overwrite-admin-edits]
//
// Migratsiya bilan bir xil parser (`parseKelajakBank`); upsert `externalId`
// bo'yicha bitta tranzaksiyada. `--update`siz mavjud savollar o'tkazib
// yuboriladi; javob berilgan savolning answerType / options / category /
// ageGroup / scoring / reverse maydonlari hech qachon o'zgarmaydi (admin
// PATCH bilan bir xil). Admin yaratgan yoki tahrirlagan savol (audit
// jurnalida `kelajak.question.update`) `--overwrite-admin-edits`siz qayta
// yozilmaydi — hisobotda ogohlantirish.
// Ko'rib chiqish qarorlari standart holda prisma/data/kelajak/review-overrides.json.

import { Prisma, PrismaClient } from '@prisma/client';
import { readFileSync } from 'node:fs';
import { KelajakQuestionData, parseKelajakBank } from '../../src/modules/kelajak/domain/bank';
import {
  ExistingKelajakQuestion,
  formatImportReport,
  ImportPlan,
  planKelajakImport,
} from '../../src/modules/kelajak/domain/import-plan';
import { KELAJAK_OVERRIDES_FILE, loadKelajakOverrides, stableKelajakId } from './build-bank-migration';

const USAGE =
  'Foydalanish: import-bank.ts <fayl.json> [--update] [--dry-run] [--overrides <fayl>] [--overwrite-admin-edits]';
const TX_TIMEOUT_MS = 120_000;
const FLAGS = ['--update', '--dry-run', '--overwrite-admin-edits'] as const;
/** Admin tahriri audit yozuvi (admin-kelajak.service). */
const ADMIN_UPDATE_ACTION = 'kelajak.question.update';

export interface ImportArgs {
  file: string;
  update: boolean;
  dryRun: boolean;
  overridesFile: string;
  overwriteAdminEdits: boolean;
}

export function parseImportArgs(argv: readonly string[]): ImportArgs {
  const overridesAt = argv.indexOf('--overrides');
  const overridesFile = overridesAt >= 0 ? argv[overridesAt + 1] : KELAJAK_OVERRIDES_FILE;
  if (!overridesFile || overridesFile.startsWith('--')) throw new Error(`--overrides: fayl kerak\n${USAGE}`);
  const rest = argv.filter((_, i) => overridesAt < 0 || (i !== overridesAt && i !== overridesAt + 1));
  const unknown = rest.filter((a) => a.startsWith('--') && !(FLAGS as readonly string[]).includes(a));
  if (unknown.length > 0) throw new Error(`Noma'lum parametr: ${unknown.join(', ')}\n${USAGE}`);
  const files = rest.filter((a) => !a.startsWith('--'));
  if (files.length !== 1) throw new Error(USAGE);
  return {
    file: files[0],
    update: rest.includes('--update'),
    dryRun: rest.includes('--dry-run'),
    overridesFile,
    overwriteAdminEdits: rest.includes('--overwrite-admin-edits'),
  };
}

type Tx = Prisma.TransactionClient;

const jsonValue = (value: unknown) => value as Prisma.InputJsonValue;
const scoringValue = (value: KelajakQuestionData['scoring']) =>
  value === null ? Prisma.DbNull : jsonValue(value);

/** Admin tahrirlagan savollar id'lari (audit jurnali). */
async function adminEditedIds(tx: Tx, ids: string[]): Promise<Set<string>> {
  if (ids.length === 0) return new Set();
  const rows = await tx.moderatorAuditLog.findMany({
    where: { action: ADMIN_UPDATE_ACTION, resourceType: 'kelajak_question', resourceId: { in: ids } },
    select: { resourceId: true },
    distinct: ['resourceId'],
  });
  return new Set(rows.flatMap((r) => (r.resourceId ? [r.resourceId] : [])));
}

/** Mavjud savollar + javoblar soni va admin tahriri; yozishdan oldin qatorlar qulflanadi. */
async function loadExisting(tx: Tx, externalIds: string[], lock: boolean): Promise<ExistingKelajakQuestion[]> {
  if (externalIds.length === 0) return [];
  // FOR UPDATE — import paytida bu savollarga yangi javob (FK) yozilmasin.
  if (lock) {
    await tx.$queryRaw`SELECT "id" FROM "kelajak_questions" WHERE "external_id" = ANY(${externalIds}) FOR UPDATE`;
  }
  const rows = await tx.kelajakQuestion.findMany({
    where: { externalId: { in: externalIds } },
    include: { _count: { select: { answers: true } } },
  });
  const edited = await adminEditedIds(tx, rows.map((r) => r.id));
  return rows.map(({ _count, ...row }) => ({
    ...row,
    answerCount: _count.answers,
    // Admin yaratgan (createdBy) yoki keyin tahrirlagan savol.
    adminEdited: row.createdBy !== null || edited.has(row.id),
  }));
}

async function applyPlan(tx: Tx, plan: ImportPlan): Promise<void> {
  if (plan.create.length > 0) {
    await tx.kelajakQuestion.createMany({
      data: plan.create.map((q) => ({
        ...q,
        id: stableKelajakId(q.externalId),
        text: jsonValue(q.text),
        options: jsonValue(q.options),
        scoring: scoringValue(q.scoring),
      })),
    });
  }
  for (const { id, changes } of plan.update) {
    const { text, options, scoring, ...plain } = changes;
    await tx.kelajakQuestion.update({
      where: { id },
      data: {
        ...plain,
        ...(text !== undefined && { text: jsonValue(text) }),
        ...(options !== undefined && { options: jsonValue(options) }),
        ...(scoring !== undefined && { scoring: scoringValue(scoring) }),
      },
    });
  }
}

async function main(): Promise<void> {
  const args = parseImportArgs(process.argv.slice(2));
  const parsed = parseKelajakBank(
    JSON.parse(readFileSync(args.file, 'utf8')),
    loadKelajakOverrides(args.overridesFile),
  );
  const externalIds = parsed.valid.flatMap((q) => (q.externalId ? [q.externalId] : []));
  const prisma = new PrismaClient();
  try {
    const plan = await prisma.$transaction(
      async (tx) => {
        const existing = await loadExisting(tx, externalIds, !args.dryRun);
        const planned = planKelajakImport({
          questions: parsed.valid,
          existing,
          update: args.update,
          overwriteAdminEdits: args.overwriteAdminEdits,
        });
        if (!args.dryRun) await applyPlan(tx, planned);
        return planned;
      },
      { timeout: TX_TIMEOUT_MS },
    );
    process.stdout.write(formatImportReport({ file: args.file, parsed, plan, dryRun: args.dryRun }));
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().catch((e) => {
    process.stderr.write(`${(e as Error).message}\n`);
    process.exit(1);
  });
}
