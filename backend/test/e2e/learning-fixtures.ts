// Savollar banki fixture'i — haqiqiy bank JSON'laridan (migratsiya bilan
// bir xil manba), resetDb bazani tozalagani uchun har testda qayta yuklanadi.

import type { PrismaClient } from '@prisma/client';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { parseBankQuestion } from '../../src/modules/learning/domain/question-bank';
import { fromApiSubject } from '../../src/modules/learning/domain/subjects';

const DATA_DIR = path.resolve(__dirname, '../../prisma/data/learning-questions');

export async function seedQuestionBank(prisma: PrismaClient): Promise<number> {
  const data = [];
  for (const file of readdirSync(DATA_DIR).filter((f) => f.endsWith('.json'))) {
    const bank = JSON.parse(readFileSync(path.join(DATA_DIR, file), 'utf8'));
    const subject = fromApiSubject(bank.subject)!;
    for (const raw of bank.questions) {
      const parsed = parseBankQuestion(raw, subject);
      if (!parsed.ok) throw new Error(parsed.error);
      const q = parsed.value;
      data.push({
        externalId: q.externalId,
        subject: q.subject,
        difficulty: q.difficulty,
        minGrade: q.minGrade,
        maxGrade: q.maxGrade,
        topic: q.topic,
        prompt: q.prompt,
        options: q.options,
        answerIndex: q.answerIndex,
        explanation: q.explanation,
      });
    }
  }
  await prisma.learningQuestion.createMany({ data });
  return data.length;
}
