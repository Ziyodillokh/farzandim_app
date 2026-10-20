// Maktab uchun Parvoz materiallari: Daily Learning fan testlari (sinf
// oralig'i fan qaysi sinfdan o'qitilishiga qarab) va tasdiqlangan
// audiokitoblar (Adabiyot). Videolar fan bilan belgilanmagan — hozircha yo'q.
// Material id: `test:<FAN>` yoki `audiobook:<uuid>`.

import { LearningSubject } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { MAX_GRADE, SUBJECT_MIN_GRADE } from '../../modules/learning/domain/subjects';

export type MaterialKind = 'AUDIOBOOK' | 'VIDEO' | 'TEST';
export type PanelSubject =
  | 'MATH'
  | 'ENGLISH'
  | 'HISTORY'
  | 'LITERATURE'
  | 'GEOGRAPHY'
  | 'BIOLOGY'
  | 'IT'
  | 'NATIVE'
  | 'PHYSICS'
  | 'CHEMISTRY'
  | 'RUSSIAN';

export interface Material {
  id: string;
  kind: MaterialKind;
  title: string;
  subject: PanelSubject;
  grades: number[];
  durationMin: number;
  questions: number;
}

/** Growth fani → panel fani. */
export const PANEL_SUBJECT: Record<LearningSubject, PanelSubject> = {
  MATH: 'MATH',
  ENGLISH: 'ENGLISH',
  NATIVE: 'NATIVE',
  HISTORY: 'HISTORY',
  BIOLOGY: 'BIOLOGY',
  GEOGRAPHY: 'GEOGRAPHY',
  PHYSICS: 'PHYSICS',
  CHEMISTRY: 'CHEMISTRY',
  INFORMATICS: 'IT',
  RUSSIAN: 'RUSSIAN',
};

const TEST_TITLE: Record<LearningSubject, string> = {
  MATH: 'Kunlik test: Matematika',
  ENGLISH: 'Kunlik test: Ingliz tili',
  NATIVE: 'Kunlik test: Ona tili',
  HISTORY: 'Kunlik test: Tarix',
  BIOLOGY: 'Kunlik test: Biologiya',
  GEOGRAPHY: 'Kunlik test: Geografiya',
  PHYSICS: 'Kunlik test: Fizika',
  CHEMISTRY: 'Kunlik test: Kimyo',
  INFORMATICS: 'Kunlik test: Informatika',
  RUSSIAN: 'Kunlik test: Rus tili',
};

/** Kunlik test — 5 savol, ~5 daqiqa. */
const DAILY_TEST_QUESTIONS = 5;
const DAILY_TEST_MINUTES = 5;
/** Yosh → sinf (1-sinf ≈ 7 yosh). */
const GRADE_AGE_OFFSET = 6;

const range = (from: number, to: number) => Array.from({ length: Math.max(0, to - from + 1) }, (_, i) => from + i);

export async function loadCatalog(prisma: PrismaService): Promise<Material[]> {
  const audiobooks = await prisma.audiobook.findMany({
    where: { status: 'approved' },
    select: { id: true, title: true, author: true, durationSec: true, ageFrom: true, ageTo: true },
    orderBy: { title: 'asc' },
  });
  const tests: Material[] = (Object.keys(TEST_TITLE) as LearningSubject[]).map((subject) => ({
    id: `test:${subject}`,
    kind: 'TEST',
    title: TEST_TITLE[subject],
    subject: PANEL_SUBJECT[subject],
    grades: range(SUBJECT_MIN_GRADE[subject], MAX_GRADE),
    durationMin: DAILY_TEST_MINUTES,
    questions: DAILY_TEST_QUESTIONS,
  }));
  const books: Material[] = audiobooks.flatMap((a) => {
    const grades = range(1, MAX_GRADE).filter((g) => a.ageFrom <= g + GRADE_AGE_OFFSET + 1 && a.ageTo >= g + GRADE_AGE_OFFSET);
    return grades.length === 0
      ? []
      : [{
          id: `audiobook:${a.id}`,
          kind: 'AUDIOBOOK' as const,
          title: `${a.title} — ${a.author}`,
          subject: 'LITERATURE' as const,
          grades,
          durationMin: Math.round((a.durationSec ?? 0) / 60),
          questions: 0,
        }];
  });
  return [...tests, ...books];
}

/** `test:MATH` → Growth fani (test bo'lmasa null). */
export function testSubjectOf(materialId: string): LearningSubject | null {
  const [kind, subject] = materialId.split(':');
  return kind === 'test' && subject && subject in TEST_TITLE ? (subject as LearningSubject) : null;
}
