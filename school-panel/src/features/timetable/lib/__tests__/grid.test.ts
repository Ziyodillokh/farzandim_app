import { describe, expect, it } from 'vitest';

import type { BellPeriod, TimetableLesson } from '@/data/contracts';
import { timetableInputSchema } from '@/data/schemas/timetable';
import {
  cellKey,
  clearDay,
  copyDay,
  filledCount,
  gridsEqual,
  isCellEmpty,
  lessonPeriods,
  mapSaveError,
  neighborCell,
  orphanLessons,
  overwriteCount,
  setCell,
  subjectChoice,
  toGrid,
  toLessons,
  validateCell,
  validateGrid,
} from '../grid';

const PERIODS: BellPeriod[] = [
  { no: 1, start: '08:00', end: '08:45', kind: 'LESSON' },
  { no: 1, start: '08:45', end: '08:50', kind: 'BREAK' },
  { no: 2, start: '08:50', end: '09:35', kind: 'LESSON' },
  { no: 2, start: '09:35', end: '09:45', kind: 'BREAK' },
  { no: 3, start: '09:45', end: '10:30', kind: 'LESSON' },
];
const NOS = [1, 2, 3];

const LESSONS: TimetableLesson[] = [
  { weekday: 1, periodNo: 1, subject: 'math', room: '205', teacherName: 'Rasulova M.' },
  { weekday: 1, periodNo: 2, subject: 'Jismoniy tarbiya', room: 'Sport zali' },
  { weekday: 2, periodNo: 3, subject: 'english' },
];

describe('lessonPeriods', () => {
  it('faqat dars davrlarini, raqam bo\'yicha tartiblab qaytaradi (tanaffussiz)', () => {
    expect(lessonPeriods(PERIODS).map((p) => p.no)).toEqual([1, 2, 3]);
    expect(lessonPeriods([...PERIODS].reverse()).map((p) => p.no)).toEqual([1, 2, 3]);
  });
});

describe('toGrid ↔ toLessons', () => {
  it('aylanib kelganda ma\'lumot o\'zgarmaydi (kun, davr tartibida)', () => {
    expect(toLessons(toGrid(LESSONS), PERIODS)).toEqual(LESSONS);
  });

  it('bo\'sh xona va o\'qituvchi yuborilmaydi; matn kesiladi', () => {
    const grid = toGrid([{ weekday: 3, periodNo: 1, subject: '  history  ', room: '   ', teacherName: null }]);
    expect(toLessons(grid, PERIODS)).toEqual([{ weekday: 3, periodNo: 1, subject: 'history' }]);
  });

  it('fani bo\'sh katak (faqat xona) yuborilmaydi', () => {
    const grid = setCell({}, 1, 1, { subject: '', room: '101', teacherName: '' });
    expect(toLessons(grid, PERIODS)).toEqual([]);
  });

  it('smenada yo\'q davr yoki noto\'g\'ri kun jadvalga tushmaydi, orphan sifatida topiladi', () => {
    const lessons: TimetableLesson[] = [...LESSONS, { weekday: 1, periodNo: 9, subject: 'math' }, { weekday: 7 as never, periodNo: 1, subject: 'math' }];
    expect(toLessons(toGrid(lessons), PERIODS)).toEqual(LESSONS);
    expect(orphanLessons(lessons, PERIODS)).toHaveLength(2);
    expect(orphanLessons(LESSONS, PERIODS)).toEqual([]);
  });

  it('natija backend sxemasidan o\'tadi (takrorsiz, chegarada)', () => {
    expect(timetableInputSchema.safeParse({ lessons: toLessons(toGrid(LESSONS), PERIODS) }).success).toBe(true);
  });
});

describe('setCell', () => {
  it('yangi grid qaytaradi, asl o\'zgarmaydi; bo\'sh qiymat katakni olib tashlaydi', () => {
    const base = toGrid(LESSONS);
    const next = setCell(base, 4, 2, { subject: 'physics', room: '', teacherName: '' });
    expect(base[cellKey(4, 2)]).toBeUndefined();
    expect(next[cellKey(4, 2)]?.subject).toBe('physics');
    expect(setCell(next, 4, 2, null)[cellKey(4, 2)]).toBeUndefined();
    expect(setCell(next, 4, 2, { subject: ' ', room: '', teacherName: '' })[cellKey(4, 2)]).toBeUndefined();
  });
});

describe('copyDay (dushanbani boshqa kunlarga)', () => {
  const monday = toGrid([
    { weekday: 1, periodNo: 1, subject: 'math', room: '205' },
    { weekday: 1, periodNo: 2, subject: 'native' },
  ]);

  it('maqsad kunlarni manba kun bilan to\'liq almashtiradi', () => {
    const grid = { ...monday, ...toGrid([{ weekday: 2, periodNo: 3, subject: 'history' }]) };
    const next = copyDay(grid, 1, [2, 3], NOS);
    expect(next[cellKey(2, 1)]).toEqual({ subject: 'math', room: '205', teacherName: '' });
    expect(next[cellKey(3, 2)]?.subject).toBe('native');
    // Manbada 3-dars yo'q — Seshanbadagi 3-dars ham bo'shaydi.
    expect(next[cellKey(2, 3)]).toBeUndefined();
    // Manba va asl grid o'zgarmaydi.
    expect(next[cellKey(1, 1)]).toEqual(monday[cellKey(1, 1)]);
    expect(grid[cellKey(2, 3)]?.subject).toBe('history');
  });

  it('nusxa mustaqil (bir katakni o\'zgartirish boshqasiga ta\'sir qilmaydi)', () => {
    const next = copyDay(monday, 1, [2], NOS);
    expect(next[cellKey(2, 1)]).not.toBe(next[cellKey(1, 1)]);
  });

  it('manba kunning o\'ziga nusxalash hech narsani o\'zgartirmaydi', () => {
    expect(gridsEqual(copyDay(monday, 1, [1], NOS), monday)).toBe(true);
  });

  it('faqat berilgan davrlar ko\'riladi', () => {
    const next = copyDay(monday, 1, [2], [1]);
    expect(next[cellKey(2, 1)]?.subject).toBe('math');
    expect(next[cellKey(2, 2)]).toBeUndefined();
  });

  it('overwriteCount: faqat haqiqatan o\'zgaradigan to\'ldirilgan kataklarni sanaydi', () => {
    const grid = { ...monday, ...toGrid([{ weekday: 2, periodNo: 1, subject: 'math', room: '205' }, { weekday: 2, periodNo: 3, subject: 'history' }, { weekday: 3, periodNo: 2, subject: 'biology' }]) };
    // Seshanba 1-dars aynan bir xil (hisoblanmaydi); 3-dars manbada yo'q (bo'shaydi); Chorshanba 2-dars almashadi.
    expect(overwriteCount(grid, 1, [2, 3], NOS)).toBe(2);
    expect(overwriteCount(grid, 1, [1], NOS)).toBe(0);
  });

  it('clearDay faqat o\'sha kunni tozalaydi', () => {
    const cleared = clearDay(toGrid(LESSONS), 1);
    expect(filledCount(cleared)).toBe(1);
    expect(cleared[cellKey(2, 3)]?.subject).toBe('english');
  });
});

describe('gridsEqual (o\'zgarish nazorati)', () => {
  it('tartibga bog\'liq emas; bo\'sh katak yo\'q katak bilan teng', () => {
    const a = toGrid(LESSONS);
    const b = toGrid([...LESSONS].reverse());
    expect(gridsEqual(a, b)).toBe(true);
    expect(gridsEqual(a, setCell(a, 5, 1, { subject: 'math', room: '', teacherName: '' }))).toBe(false);
    expect(gridsEqual(a, setCell(a, 1, 1, { ...a[cellKey(1, 1)]!, room: '206' }))).toBe(false);
  });
});

describe('subjectChoice', () => {
  it('ma\'lum kalit, erkin matn va bo\'sh qiymatni ajratadi', () => {
    expect(subjectChoice('math')).toEqual({ kind: 'known', key: 'math' });
    expect(subjectChoice(' Texnologiya ')).toEqual({ kind: 'custom', text: 'Texnologiya' });
    expect(subjectChoice('Math')).toEqual({ kind: 'custom', text: 'Math' });
    expect(subjectChoice('  ')).toEqual({ kind: 'none' });
  });
});

describe('validatePeriod / validateGrid', () => {
  it('fansiz to\'ldirilgan katak va uzun matn xato; bo\'sh katak xato emas', () => {
    expect(validateCell(undefined)).toBeNull();
    expect(validateCell({ subject: '', room: '', teacherName: '' })).toBeNull();
    expect(validateCell({ subject: '', room: '12', teacherName: '' })).toBe('subjectRequired');
    expect(validateCell({ subject: 'x'.repeat(61), room: '', teacherName: '' })).toBe('subjectTooLong');
    expect(validateCell({ subject: 'x'.repeat(60), room: '', teacherName: '' })).toBeNull();
    expect(validateCell({ subject: 'math', room: 'r'.repeat(21), teacherName: '' })).toBe('roomTooLong');
    expect(validateCell({ subject: 'math', room: '', teacherName: 't'.repeat(81) })).toBe('teacherTooLong');
  });

  it('faqat smena davrlaridagi kataklar tekshiriladi', () => {
    const grid = { ...toGrid(LESSONS), [cellKey(2, 1)]: { subject: '', room: '5', teacherName: '' }, [cellKey(2, 9)]: { subject: '', room: '5', teacherName: '' } };
    expect(validateGrid(grid, PERIODS)).toEqual({ [cellKey(2, 1)]: 'subjectRequired' });
    expect(isCellEmpty(grid[cellKey(2, 9)])).toBe(false);
  });
});

describe('mapSaveError (400 → kataklar)', () => {
  const sent: TimetableLesson[] = [
    { weekday: 1, periodNo: 1, subject: 'math' },
    { weekday: 2, periodNo: 3, subject: 'english' },
    { weekday: 4, periodNo: 2, subject: 'history' },
  ];

  it('yuborilgan ro\'yxat indeksi (lessons.N / lessons[N]) orqali katakka bog\'laydi', () => {
    const map = mapSaveError('lessons.1.periodNo must not be greater than 6; lessons[2].subject must be shorter than or equal to 60 characters', sent);
    expect(map.cells).toEqual({ [cellKey(2, 3)]: 'invalidPeriod', [cellKey(4, 2)]: 'subjectTooLong' });
    expect(map.hasUnmapped).toBe(false);
  });

  it('matndagi «weekday W … period P» juftligidan katakni topadi (har ikki tartibda)', () => {
    expect(mapSaveError('duplicate lesson for weekday 2, periodNo 3', sent).cells).toEqual({ [cellKey(2, 3)]: 'duplicate' });
    expect(mapSaveError('period 2 is not part of the class shift (weekday 4)', sent).cells).toEqual({ [cellKey(4, 2)]: 'invalidPeriod' });
  });

  it('bog\'lab bo\'lmaydigan xabar — umumiy xato; qisman bog\'langanda ham belgilanadi', () => {
    expect(mapSaveError('Bad Request', sent)).toEqual({ cells: {}, hasUnmapped: true });
    const partial = mapSaveError('lessons.0.subject should not be empty; HTTP 400', sent);
    expect(partial.cells).toEqual({ [cellKey(1, 1)]: 'subjectRequired' });
    expect(partial.hasUnmapped).toBe(true);
  });

  it('mavjud bo\'lmagan indeks bog\'lanmaydi', () => {
    expect(mapSaveError('lessons.9.weekday invalid', sent)).toEqual({ cells: {}, hasUnmapped: true });
  });
});

describe('neighborCell (strelka bilan yurish)', () => {
  it('to\'rning chetida to\'xtaydi, aylanmaydi', () => {
    expect(neighborCell('1:1', 'left', NOS)).toBeNull();
    expect(neighborCell('1:1', 'up', NOS)).toBeNull();
    expect(neighborCell('6:3', 'right', NOS)).toBeNull();
    expect(neighborCell('6:3', 'down', NOS)).toBeNull();
  });

  it('qo\'shni katakka o\'tadi', () => {
    expect(neighborCell('2:2', 'left', NOS)).toBe('1:2');
    expect(neighborCell('2:2', 'right', NOS)).toBe('3:2');
    expect(neighborCell('2:2', 'up', NOS)).toBe('2:1');
    expect(neighborCell('2:2', 'down', NOS)).toBe('2:3');
  });

  it('davr raqamlari ketma-ket bo\'lmasa ham qatorlar tartibida yuradi', () => {
    expect(neighborCell('3:2', 'down', [2, 4, 7])).toBe('3:4');
    expect(neighborCell('3:99', 'down', NOS)).toBeNull();
  });
});
