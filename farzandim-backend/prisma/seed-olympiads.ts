/**
 * Sprint 5.4: seed 3 demo olympiads with questions + synthetic attempts for
 * Konkurslar admin page.
 *
 * Usage on server:
 *   tsx prisma/seed-olympiads.ts
 */
import 'dotenv/config';
import { prisma } from '../src/lib/prisma';

interface QuestionSeed {
  text: string;
  options: string[];
  correctIndex: number;
  points: number;
}

interface OlympiadSeed {
  title: string;
  description: string;
  subject: string;
  ageFrom: number;
  ageTo: number;
  type: 'test' | 'creative' | 'mixed';
  difficulty: 'oson' | "o'rta" | 'qiyin';
  startsInHours: number;
  endsInHours: number;
  durationMin: number;
  xpReward: number;
  status: 'draft' | 'published' | 'archived';
  questions: QuestionSeed[];
}

const SEED: OlympiadSeed[] = [
  {
    title: "Iste'dod Uchquni — Matematika",
    description: "Asosiy matematik amallar va sodda mantiqiy savollar.",
    subject: 'Matematika',
    ageFrom: 9,
    ageTo: 12,
    type: 'test',
    difficulty: "o'rta",
    startsInHours: 24,
    endsInHours: 24 + 24 * 7,
    durationMin: 30,
    xpReward: 100,
    status: 'published',
    questions: [
      { text: '17 + 8 = ?', options: ['23', '25', '27', '24'], correctIndex: 1, points: 10 },
      { text: '7 × 6 = ?', options: ['42', '36', '48', '45'], correctIndex: 0, points: 10 },
      { text: '100 - 37 = ?', options: ['63', '73', '57', '67'], correctIndex: 0, points: 10 },
      { text: 'Qaysi son juft son?', options: ['7', '11', '14', '21'], correctIndex: 2, points: 10 },
      { text: "144 ning ildizi nechiga teng?", options: ['10', '11', '12', '13'], correctIndex: 2, points: 15 },
    ],
  },
  {
    title: "Ona tili viktorinasi",
    description: "O'zbek tili va adabiyot bo'yicha viktorina.",
    subject: 'Ona tili',
    ageFrom: 6,
    ageTo: 9,
    type: 'test',
    difficulty: 'oson',
    startsInHours: -24, // boshlangan
    endsInHours: 24 * 3,
    durationMin: 20,
    xpReward: 50,
    status: 'published',
    questions: [
      { text: '"Alpomish" qaysi xalq dostoni?', options: ["O'zbek", 'Qozoq', 'Tatar', 'Boshqird'], correctIndex: 0, points: 10 },
      { text: 'Bog\' so\'zining ko\'pligi?', options: ['Boglari', 'Boglar', 'Bog\'lar', 'Boglarim'], correctIndex: 2, points: 10 },
      { text: 'Yetti ning sonidan keyin keladigan son?', options: ['Olti', 'Sakkiz', 'Toqqiz', 'O\'n'], correctIndex: 1, points: 10 },
    ],
  },
  {
    title: 'IT mantiqiy masala — Algoritm',
    description: "Boshlang'ich algoritmik fikrlash bo'yicha qoralama konkurs.",
    subject: 'IT',
    ageFrom: 13,
    ageTo: 16,
    type: 'mixed',
    difficulty: 'qiyin',
    startsInHours: 48,
    endsInHours: 48 + 24 * 14,
    durationMin: 45,
    xpReward: 200,
    status: 'draft',
    questions: [],
  },
];

async function main(): Promise<void> {
  // Reset prior demo data (only olympiad models)
  await prisma.olympiadAttempt.deleteMany();
  await prisma.olympiadQuestion.deleteMany();
  await prisma.olympiad.deleteMany();

  let createdCount = 0;
  let attemptCount = 0;
  const children = await prisma.child.findMany({ take: 5, select: { id: true, name: true } });

  for (const o of SEED) {
    const start = new Date(Date.now() + o.startsInHours * 3_600_000);
    const end = new Date(Date.now() + o.endsInHours * 3_600_000);
    const olympiad = await prisma.olympiad.create({
      data: {
        title: o.title,
        description: o.description,
        subject: o.subject,
        ageFrom: o.ageFrom,
        ageTo: o.ageTo,
        type: o.type,
        difficulty: o.difficulty,
        startTime: start,
        endTime: end,
        durationMin: o.durationMin,
        xpReward: o.xpReward,
        status: o.status,
        questions: {
          create: o.questions.map((q, i) => ({
            text: q.text,
            options: q.options,
            correctIndex: q.correctIndex,
            points: q.points,
            orderIdx: i,
          })),
        },
      },
    });
    createdCount += 1;

    // Synthetic attempts for the second olympiad (the "live" one) only.
    if (o.subject === 'Ona tili') {
      const totalPoints = o.questions.reduce((sum, q) => sum + q.points, 0);
      const total = o.questions.length;
      for (let i = 0; i < children.length; i += 1) {
        const c = children[i]!;
        const correct = Math.max(0, total - (i % 3));
        const score = Math.round(totalPoints * (correct / total));
        const finished = i % 4 !== 0; // 3/5 finished, others in progress
        await prisma.olympiadAttempt.create({
          data: {
            olympiadId: olympiad.id,
            childId: c.id,
            status: finished ? 'finished' : 'in_progress',
            score: finished ? score : Math.round(score * 0.4),
            totalPoints,
            correctAnswers: finished ? correct : Math.max(0, correct - 1),
            questionsTotal: total,
            timeSec: finished ? 600 + i * 90 : 300,
            startedAt: new Date(Date.now() - (i + 1) * 3_600_000),
            finishedAt: finished ? new Date(Date.now() - i * 1_800_000) : null,
          },
        });
        attemptCount += 1;
      }
    }
  }

  console.log(`Olympiads seeded: ${createdCount}`);
  console.log(`Attempts seeded: ${attemptCount}`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
