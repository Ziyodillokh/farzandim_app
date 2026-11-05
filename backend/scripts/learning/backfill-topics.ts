// Eski erkin matnli mavzulardan (`learning_questions.topic.uz`) mavzular
// katalogini (`learning_topics`) to'ldirish — qayta ishga tushirish xavfsiz
// (idempotent): faqat mavzusiz (`topic_id IS NULL`) savollar ko'riladi.
//
//   npx tsx scripts/learning/backfill-topics.ts            # DRY-RUN: faqat hisobot, bazaga yozilmaydi
//   npx tsx scripts/learning/backfill-topics.ts --apply    # yozadi (bitta tranzaksiya)
//
// Serverda: cd ~/new-platform/backend && ./node_modules/.bin/tsx scripts/learning/backfill-topics.ts [--apply]
//
// Har fan uchun: mavzusiz savollar normallashtirilgan `topic.uz` bo'yicha
// guruhlanadi; shu fanda shu nomli mavzu bor bo'lsa — qayta ishlatiladi
// (o'zgartirilmaydi), yo'q bo'lsa yaratiladi (kalit = sarlavhadan slug, to'qnashsa
// `-2`, sarlavha = savolning topic JSON'i, sinflar = savollarning min/maxi,
// pozitsiya = (minGrade, title.uz) tartibi). Keyin savollar bog'lanadi.

import { LearningQuestionStatus, Prisma, PrismaClient } from '@prisma/client';
import {
  BackfillExistingTopic,
  BackfillGroup,
  BackfillPlan,
  planTopicBackfill,
} from '../../src/modules/learning/domain/topic-backfill';
import { toApiSubject } from '../../src/modules/learning/domain/subjects';
import { MIN_TOPIC_QUESTIONS } from '../../src/modules/learning/domain/topic-mastery';

const USAGE = 'Foydalanish: backfill-topics.ts [--apply]';
const TX_TIMEOUT_MS = 120_000;

export interface UnderfilledTopic {
  subject: string;
  key: string;
  activeQuestions: number;
}

export interface BackfillReport {
  apply: boolean;
  topicsCreated: number;
  topicsReused: number;
  /** Dry-run'da — bog'lanadigan, apply'da — haqiqatda bog'langan savollar. */
  questionsLinked: number;
  skipped: BackfillPlan['skipped'];
  /** Skript tugagach katalogdagi MIN_TOPIC_QUESTIONS dan kam faol savolli mavzular. */
  underfilled: UnderfilledTopic[];
  /** Fan bo'yicha: yangi mavzular va bog'lanadigan savollar. */
  bySubject: { subject: string; topicsCreated: number; topicsReused: number; questionsLinked: number }[];
}

export function parseArgs(argv: readonly string[]): { apply: boolean } {
  const unknown = argv.filter((a) => a !== '--apply');
  if (unknown.length > 0) throw new Error(`Noma'lum parametr: ${unknown.join(', ')}\n${USAGE}`);
  return { apply: argv.includes('--apply') };
}

export async function runBackfill(
  prisma: PrismaClient,
  options: { apply: boolean },
): Promise<BackfillReport> {
  const plan = await prisma.$transaction(
    async (tx) => {
      const { questions, existing } = await load(tx);
      const planned = planTopicBackfill(questions, existing);
      const linked = options.apply ? await applyPlan(tx, planned) : null;
      return { planned, existing, linked };
    },
    { timeout: TX_TIMEOUT_MS },
  );
  return buildReport(plan.planned, plan.existing, options.apply, plan.linked);
}

async function load(tx: Prisma.TransactionClient) {
  const [rows, topics, counts] = await Promise.all([
    tx.learningQuestion.findMany({
      where: { topicId: null },
      select: { id: true, externalId: true, subject: true, topic: true, minGrade: true, maxGrade: true, status: true },
    }),
    tx.learningTopic.findMany({ select: { id: true, subject: true, key: true, title: true, position: true } }),
    tx.learningQuestion.groupBy({
      by: ['topicId'],
      where: { topicId: { not: null }, status: LearningQuestionStatus.ACTIVE },
      _count: { _all: true },
    }),
  ]);
  const activeByTopic = new Map(counts.map((c) => [c.topicId, c._count._all]));
  const existing: BackfillExistingTopic[] = topics.map((t) => ({
    id: t.id,
    subject: t.subject,
    key: t.key,
    titleUz: String((t.title as { uz?: unknown } | null)?.uz ?? ''),
    position: t.position,
    activeQuestions: activeByTopic.get(t.id) ?? 0,
  }));
  const questions = rows.map((q) => ({
    id: q.id,
    externalId: q.externalId,
    subject: q.subject,
    topic: q.topic,
    minGrade: q.minGrade,
    maxGrade: q.maxGrade,
    isActive: q.status === LearningQuestionStatus.ACTIVE,
  }));
  return { questions, existing };
}

/** Yangi mavzularni yaratadi va savollarni bog'laydi; haqiqatda bog'langan savollar soni. */
async function applyPlan(tx: Prisma.TransactionClient, plan: BackfillPlan): Promise<number> {
  let linked = 0;
  for (const group of plan.groups) {
    const topicId = group.existingTopicId ?? (await createTopic(tx, group));
    const result = await tx.learningQuestion.updateMany({
      where: { id: { in: group.questionIds }, topicId: null },
      data: { topicId },
    });
    linked += result.count;
  }
  return linked;
}

async function createTopic(tx: Prisma.TransactionClient, group: BackfillGroup): Promise<string> {
  const created = await tx.learningTopic.create({
    data: {
      subject: group.subject,
      key: group.key,
      title: group.title,
      minGrade: group.minGrade,
      maxGrade: group.maxGrade,
      position: group.position,
    },
    select: { id: true },
  });
  return created.id;
}

function buildReport(
  plan: BackfillPlan,
  existing: readonly BackfillExistingTopic[],
  apply: boolean,
  linkedByApply: number | null,
): BackfillReport {
  const touched = new Set(plan.groups.map((g) => `${g.subject}:${g.key}`));
  const untouched = existing.filter((t) => !touched.has(`${t.subject}:${t.key}`));
  const underfilled = [
    ...plan.groups.map((g) => ({ subject: g.subject, key: g.key, activeQuestions: g.activeQuestions })),
    ...untouched.map((t) => ({ subject: t.subject, key: t.key, activeQuestions: t.activeQuestions })),
  ]
    .filter((t) => t.activeQuestions < MIN_TOPIC_QUESTIONS)
    .map((t) => ({ ...t, subject: toApiSubject(t.subject) }))
    .sort((a, b) => a.subject.localeCompare(b.subject) || a.key.localeCompare(b.key));

  const subjects = [...new Set(plan.groups.map((g) => g.subject))].sort();
  const bySubject = subjects.map((subject) => {
    const groups = plan.groups.filter((g) => g.subject === subject);
    return {
      subject: toApiSubject(subject),
      topicsCreated: groups.filter((g) => !g.existingTopicId).length,
      topicsReused: groups.filter((g) => g.existingTopicId).length,
      questionsLinked: groups.reduce((sum, g) => sum + g.questionIds.length, 0),
    };
  });
  return {
    apply,
    topicsCreated: plan.groups.filter((g) => !g.existingTopicId).length,
    topicsReused: plan.groups.filter((g) => g.existingTopicId).length,
    questionsLinked: linkedByApply ?? plan.groups.reduce((sum, g) => sum + g.questionIds.length, 0),
    skipped: plan.skipped,
    underfilled,
    bySubject,
  };
}

export function formatReport(report: BackfillReport): string {
  const lines = [
    report.apply ? 'MAVZULAR BACKFILL — YOZILDI (--apply)' : 'MAVZULAR BACKFILL — DRY-RUN (bazaga yozilmadi; yozish uchun --apply)',
    '',
    `Mavzular yaratiladi: ${report.topicsCreated}`,
    `Mavjud mavzular qayta ishlatiladi: ${report.topicsReused}`,
    `Savollar bog'lanadi: ${report.questionsLinked}`,
    `O'tkazib yuborilgan (yaroqsiz topic): ${report.skipped.length}`,
    '',
    'Fan bo\'yicha:',
    ...report.bySubject.map(
      (s) => `  ${s.subject.padEnd(12)} yangi ${s.topicsCreated}, mavjud ${s.topicsReused}, savol ${s.questionsLinked}`,
    ),
    '',
    `${MIN_TOPIC_QUESTIONS} tadan kam faol savolli mavzular (ilovada "mavjud" emas): ${report.underfilled.length}`,
    ...report.underfilled.map((t) => `  ${t.subject}/${t.key}: ${t.activeQuestions}`),
  ];
  if (report.skipped.length > 0) {
    lines.push('', "O'tkazib yuborilgan savollar:", ...report.skipped.map((s) => `  ${s.questionId}: ${s.reason}`));
  }
  return `${lines.join('\n')}\n`;
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const prisma = new PrismaClient();
  try {
    process.stdout.write(formatReport(await runBackfill(prisma, args)));
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
