import { buildCells, CellAttempt, cellKey, LEARNING_MIN_COHORT, mondayOf, totalsOf } from './learning-cells';

const MONDAY = '2026-10-19';
const attempt = (childId: string, schoolClassId: string | null, day: string, correct: number): CellAttempt => ({
  childId,
  schoolClassId,
  day,
  correct,
  total: 5,
  donEarned: correct * 2,
});
const kids = (prefix: string, n: number) => Array.from({ length: n }, (_, i) => `${prefix}${i}`);

describe('learning-cells', () => {
  it('kataklar: urinish paytidagi sinf va hafta dushanbasi bo\'yicha; sinfsiz (bog\'lashdan oldingi) urinish hisobga olinmaydi', () => {
    const cells = buildCells([
      attempt('a1', 'cls-a', '2026-10-21', 5),
      attempt('a1', 'cls-a', '2026-10-25', 3),
      attempt('a2', 'cls-a', '2026-10-18', 4),
      attempt('a2', null, MONDAY, 5),
    ]);
    expect([...cells.keys()].sort()).toEqual([cellKey('cls-a', '2026-10-12'), cellKey('cls-a', MONDAY)]);
    expect(cells.get(cellKey('cls-a', MONDAY))).toMatchObject({ classId: 'cls-a', weekStart: MONDAY, tasks: 2, scoreSum: 160, don: 16 });
    expect(cells.get(cellKey('cls-a', MONDAY))?.active.size).toBe(1);
    expect(mondayOf('2026-10-25')).toBe(MONDAY);
  });

  it('boshqa sinfga o\'tgan bola: har urinish o\'z paytidagi sinfida qoladi', () => {
    const cells = buildCells([attempt('k', 'cls-a', MONDAY, 5), attempt('k', 'cls-b', '2026-10-20', 1)]);
    expect(cells.get(cellKey('cls-a', MONDAY))).toMatchObject({ tasks: 1, scoreSum: 100 });
    expect(cells.get(cellKey('cls-b', MONDAY))).toMatchObject({ tasks: 1, scoreSum: 20 });
  });

  it('faol bola yo\'q — natija 0 (yashiradigan narsa yo\'q)', () => {
    expect(totalsOf([])).toEqual({ activeStudents: 0, completedTasks: 0, avgScore: null, donPoints: 0, suppressed: false });
    expect(totalsOf([undefined])).toEqual(totalsOf([]));
  });

  it(`${LEARNING_MIN_COHORT} nafardan kam faol — natijalar yashirin, faollar soni ko'rinadi`, () => {
    const small = buildCells(kids('b', LEARNING_MIN_COHORT - 1).map((id) => attempt(id, 'cls-b', MONDAY, 1)));
    expect(totalsOf([...small.values()])).toEqual({ activeStudents: 4, completedTasks: null, avgScore: null, donPoints: null, suppressed: true });
  });

  it('aralash: natijalar faqat ochiq kataklardan — jamidan ayirib kichik guruh tiklanmaydi', () => {
    const cells = buildCells([...kids('a', 5).map((id) => attempt(id, 'cls-a', MONDAY, 4)), ...kids('b', 2).map((id) => attempt(id, 'cls-b', MONDAY, 0))]);
    const all = totalsOf([...cells.values()]);
    const openOnly = totalsOf([cells.get(cellKey('cls-a', MONDAY))]);
    expect(all).toEqual({ activeStudents: 7, completedTasks: 5, avgScore: 80, donPoints: 40, suppressed: false });
    expect(openOnly).toEqual({ activeStudents: 5, completedTasks: 5, avgScore: 80, donPoints: 40, suppressed: false });
    expect(totalsOf([cells.get(cellKey('cls-b', MONDAY))])).toMatchObject({ activeStudents: 2, suppressed: true, completedTasks: null });
  });
});
