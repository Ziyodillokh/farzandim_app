import {
  formFor,
  groupOffset,
  isExpired,
  isMixedForm,
  levelForAge,
  nextAvailableAt,
  normGroupForAge,
  normKey,
  resolveIqAge,
  RETAKE_DAYS,
} from './levels';

describe('IQ darajalari (docs/IQ-REJA.md §1)', () => {
  it.each([
    [8, null],
    [9, 1],
    [10, 1],
    [11, 2],
    [12, 2],
    [13, 3],
    [14, 3],
    [15, 4],
    [16, 4],
    [17, 5],
    [20, 5],
    [21, null],
  ])('%i yosh → %p daraja', (age, level) => {
    expect(levelForAge(age)).toBe(level);
  });

  it('norma guruhi: har yosh alohida, 17–20 bitta guruh', () => {
    expect(normGroupForAge(9)).toBe('9');
    expect(normGroupForAge(16)).toBe('16');
    expect(normGroupForAge(17)).toBe('17-20');
    expect(normGroupForAge(20)).toBe('17-20');
    expect(normGroupForAge(8)).toBeNull();
  });

  it("dastlabki ma'lumotnoma: darajaning kichik yoshi −0.25, kattasi +0.25", () => {
    expect(['9', '11', '13', '15'].map(groupOffset)).toEqual([-0.25, -0.25, -0.25, -0.25]);
    expect(['10', '12', '14', '16'].map(groupOffset)).toEqual([0.25, 0.25, 0.25, 0.25]);
    expect(groupOffset('17-20')).toBe(0);
  });

  it("yosh: tug'ilgan sana ustun, yo'q bo'lsa age; ikkalasi yo'q — AGE_REQUIRED", () => {
    expect(resolveIqAge({ birthDate: '2015-10-22', age: 16 }, '2026-10-21')).toEqual({
      status: 'OK',
      age: 10,
      level: 1,
    });
    expect(resolveIqAge({ birthDate: null, age: 13 }, '2026-10-21')).toEqual({
      status: 'OK',
      age: 13,
      level: 3,
    });
    expect(resolveIqAge({ birthDate: null, age: 7 }, '2026-10-21')).toEqual({
      status: 'AGE_OUT_OF_RANGE',
      age: 7,
      level: null,
    });
    expect(resolveIqAge({ birthDate: null, age: null }, '2026-10-21').status).toBe('AGE_REQUIRED');
  });

  it('yangi sessiya — aralash forma, almashadi: C → D → C', () => {
    expect([0, 1, 2].map((n) => formFor(3, n))).toEqual(['L3C', 'L3D', 'L3C']);
  });

  it('norma kaliti: aralash forma alohida, rasmli — eski guruh', () => {
    expect([isMixedForm('L2C'), isMixedForm('L2D'), isMixedForm('L2A')]).toEqual([true, true, false]);
    expect(normKey('L2C', '11')).toBe('mix:11');
    expect(normKey('L5D', '17-20')).toBe('mix:17-20');
    expect(normKey('L2B', '11')).toBe('11');
  });

  it('qayta topshirish 180 kundan keyin, sessiya 24 soatda eskiradi', () => {
    const done = new Date('2026-01-01T10:00:00Z');
    expect(nextAvailableAt(done)?.getTime()).toBe(done.getTime() + RETAKE_DAYS * 86_400_000);
    expect(nextAvailableAt(null)).toBeNull();
    expect(isExpired(done, new Date('2026-01-02T09:59:00Z'))).toBe(false);
    expect(isExpired(done, new Date('2026-01-02T10:01:00Z'))).toBe(true);
  });
});
