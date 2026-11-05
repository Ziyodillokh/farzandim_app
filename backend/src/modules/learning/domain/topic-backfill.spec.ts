import { LearningSubject } from '@prisma/client';
import {
  BackfillExistingTopic,
  BackfillQuestion,
  normalizeTopicName,
  planTopicBackfill,
  slugifyTopic,
  uniqueTopicKey,
} from './topic-backfill';
import { isValidTopicKey, TOPIC_KEY_MAX } from './topic-input';

const q = (
  id: string,
  uz: string,
  grades: [number, number],
  patch: Partial<BackfillQuestion> = {},
): BackfillQuestion => ({
  id,
  externalId: id,
  subject: LearningSubject.MATH,
  topic: { uz, ru: `${uz}-ru`, en: `${uz}-en` },
  minGrade: grades[0],
  maxGrade: grades[1],
  isActive: true,
  ...patch,
});

describe('slugifyTopic', () => {
  it.each([
    ['Kasrlar', 'kasrlar'],
    ['Oddiy kasrlar', 'oddiy-kasrlar'],
    ['Oʻzbek tili', 'ozbek-tili'],
    ["G'oya va ma'no", 'goya-va-mano'],
    ['  Foizlar   va  nisbat  ', 'foizlar-va-nisbat'],
    ['Дроби и проценты', 'drobi-i-protsenty'],
    ['Ўзбек тили', 'ozbek-tili'],
    ['Équations (2-daraja)', 'equations-2-daraja'],
    ['Quyosh tizimi: 8 sayyora', 'quyosh-tizimi-8-sayyora'],
  ])('"%s" → "%s"', (title, expected) => {
    expect(slugifyTopic(title)).toBe(expected);
  });

  it('har doim yaroqli kalit: belgilar bo\'lmasa "topic", uzun matn qirqiladi', () => {
    expect(slugifyTopic('???')).toBe('topic');
    expect(slugifyTopic('')).toBe('topic');
    const long = slugifyTopic(`${'a'.repeat(TOPIC_KEY_MAX - 1)} bbbb`);
    expect(long.length).toBeLessThanOrEqual(TOPIC_KEY_MAX);
    expect(isValidTopicKey(long)).toBe(true);
    expect(isValidTopicKey(slugifyTopic('Ёё ъь'))).toBe(true);
  });
});

describe('normalizeTopicName', () => {
  it('bo\'shliq va registr farqi hisobga olinmaydi', () => {
    expect(normalizeTopicName('  Oddiy   KASRLAR ')).toBe('oddiy kasrlar');
  });
});

describe('uniqueTopicKey', () => {
  it('band kalitga qo\'shimcha qo\'shadi va 80 belgidan oshmaydi', () => {
    expect(uniqueTopicKey('kasrlar', new Set())).toBe('kasrlar');
    expect(uniqueTopicKey('kasrlar', new Set(['kasrlar']))).toBe('kasrlar-2');
    expect(uniqueTopicKey('kasrlar', new Set(['kasrlar', 'kasrlar-2']))).toBe('kasrlar-3');
    const max = 'a'.repeat(TOPIC_KEY_MAX);
    const next = uniqueTopicKey(max, new Set([max]));
    expect(next.length).toBeLessThanOrEqual(TOPIC_KEY_MAX);
    expect(next.endsWith('-2')).toBe(true);
    expect(isValidTopicKey(next)).toBe(true);
  });
});

describe('planTopicBackfill', () => {
  it('normallashtirilgan topic.uz bo\'yicha guruhlaydi; sinf oralig\'i min/max; sarlavha — birinchi savolniki', () => {
    const plan = planTopicBackfill(
      [
        q('math-02', 'Kasrlar', [5, 9]),
        q('math-01', ' kasrlar ', [3, 6], { topic: { uz: ' kasrlar ', ru: 'Дроби', en: 'Fractions' } }),
        q('math-03', 'Foizlar', [6, 10], { isActive: false }),
      ],
      [],
    );
    expect(plan.skipped).toEqual([]);
    const fractions = plan.groups.find((g) => g.key === 'kasrlar')!;
    expect(fractions).toMatchObject({
      existingTopicId: null,
      minGrade: 3,
      maxGrade: 9,
      questionIds: ['math-01', 'math-02'],
      activeQuestions: 2,
      title: { uz: 'kasrlar', ru: 'Дроби', en: 'Fractions' },
    });
    expect(plan.groups.find((g) => g.key === 'foizlar')).toMatchObject({
      questionIds: ['math-03'],
      activeQuestions: 0,
    });
  });

  it('pozitsiya: fan ichida (minGrade, title.uz) bo\'yicha 0 dan; fanlar mustaqil', () => {
    const plan = planTopicBackfill(
      [
        q('m1', 'Yuqori sinf', [9, 11]),
        q('m2', 'Boshlang\'ich B', [1, 2]),
        q('m3', 'Boshlang\'ich A', [1, 2]),
        q('p1', 'Mexanika', [7, 9], { subject: LearningSubject.PHYSICS }),
      ],
      [],
    );
    const math = plan.groups.filter((g) => g.subject === 'MATH');
    expect(math.map((g) => [g.title.uz, g.position])).toEqual([
      ["Boshlang'ich A", 0],
      ["Boshlang'ich B", 1],
      ['Yuqori sinf', 2],
    ]);
    expect(plan.groups.find((g) => g.subject === 'PHYSICS')!.position).toBe(0);
  });

  it('kalit to\'qnashuvi: bir xil slug berayotgan turli nomlar -2 oladi (deterministik)', () => {
    const plan = planTopicBackfill([q('a', "O'zbek", [1, 2]), q('b', 'Ozbek', [1, 2])], []);
    expect(plan.groups.map((g) => g.key).sort()).toEqual(['ozbek', 'ozbek-2']);
    const again = planTopicBackfill([q('b', 'Ozbek', [1, 2]), q('a', "O'zbek", [1, 2])], []);
    expect(again.groups).toEqual(plan.groups);
  });

  it('mavjud mavzu qayta ishlatiladi (nom bo\'yicha), o\'zgartirilmaydi; yangilari undan keyin', () => {
    const existing: BackfillExistingTopic[] = [
      { id: 't-1', subject: LearningSubject.MATH, key: 'kasrlar', titleUz: 'Kasrlar', position: 4, activeQuestions: 12 },
    ];
    const plan = planTopicBackfill([q('x', 'KASRLAR', [5, 6]), q('y', 'Yangi mavzu', [5, 6])], existing);
    expect(plan.groups.find((g) => g.existingTopicId === 't-1')).toMatchObject({
      key: 'kasrlar',
      questionIds: ['x'],
      activeQuestions: 13,
    });
    const created = plan.groups.find((g) => g.existingTopicId === null)!;
    expect(created).toMatchObject({ key: 'yangi-mavzu', position: 5 });
  });

  it('mavjud kalit boshqa nomga tegishli bo\'lsa yangi mavzu qo\'shimcha oladi', () => {
    const existing: BackfillExistingTopic[] = [
      { id: 't-1', subject: LearningSubject.MATH, key: 'kasrlar', titleUz: 'Oddiy kasrlar', position: 0, activeQuestions: 3 },
    ];
    const plan = planTopicBackfill([q('x', 'Kasrlar', [5, 6])], existing);
    expect(plan.groups).toHaveLength(1);
    expect(plan.groups[0]).toMatchObject({ existingTopicId: null, key: 'kasrlar-2', position: 1 });
  });

  it('boshqa fanning mavzusi mavjud bo\'lsa ham alohida (fan ichida noyob)', () => {
    const existing: BackfillExistingTopic[] = [
      { id: 't-1', subject: LearningSubject.PHYSICS, key: 'kasrlar', titleUz: 'Kasrlar', position: 0, activeQuestions: 0 },
    ];
    const plan = planTopicBackfill([q('x', 'Kasrlar', [5, 6])], existing);
    expect(plan.groups[0]).toMatchObject({ existingTopicId: null, key: 'kasrlar', position: 0 });
  });

  it('yaroqsiz topic JSON o\'tkazib yuboriladi va hisobotga tushadi', () => {
    const plan = planTopicBackfill(
      [q('ok', 'Kasrlar', [1, 2]), q('bad1', 'x', [1, 2], { topic: null }), q('bad2', 'x', [1, 2], { topic: { ru: 'Дроби' } })],
      [],
    );
    expect(plan.groups).toHaveLength(1);
    expect(plan.skipped.map((s) => s.questionId)).toEqual(['bad1', 'bad2']);
  });

  it('barcha rejalangan kalitlar yaroqli', () => {
    const plan = planTopicBackfill(
      ['Oʻzbek tili', 'Дроби', '???', 'A'.repeat(70)].map((t, i) => q(`q${i}`, t, [1, 11])),
      [],
    );
    expect(plan.groups.every((g) => isValidTopicKey(g.key))).toBe(true);
  });

  it('kiruvchi massivlarni o\'zgartirmaydi', () => {
    const input = [q('b', 'B', [1, 2]), q('a', 'A', [1, 2])];
    const copy = JSON.stringify(input);
    planTopicBackfill(input, []);
    expect(JSON.stringify(input)).toBe(copy);
  });
});
