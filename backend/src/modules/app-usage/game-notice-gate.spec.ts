import { GAME_NOTICE_DEDUP_MS, GAME_NOTICE_MAX_AGE_MS, GameNoticeGate } from './game-notice-gate';

describe('GameNoticeGate', () => {
  const NOW = Date.parse('2026-11-14T08:00:00.000Z');

  it("bir o'yin bo'yicha 5 daqiqada faqat bitta push", () => {
    const gate = new GameNoticeGate();

    expect(gate.shouldNotify('child-1', 'com.game', undefined, NOW)).toBe(true);
    expect(gate.shouldNotify('child-1', 'com.game', undefined, NOW + 60_000)).toBe(false);
    expect(gate.shouldNotify('child-1', 'com.game', undefined, NOW + GAME_NOTICE_DEDUP_MS)).toBe(true);
  });

  it("boshqa o'yin yoki boshqa bola alohida hisoblanadi", () => {
    const gate = new GameNoticeGate();

    expect(gate.shouldNotify('child-1', 'com.game', undefined, NOW)).toBe(true);
    expect(gate.shouldNotify('child-1', 'com.other', undefined, NOW)).toBe(true);
    expect(gate.shouldNotify('child-2', 'com.game', undefined, NOW)).toBe(true);
  });

  it('10 daqiqadan eski hodisa yuborilmaydi va dedup vaqtini egallamaydi', () => {
    const gate = new GameNoticeGate();
    const stale = new Date(NOW - GAME_NOTICE_MAX_AGE_MS - 1).toISOString();

    expect(gate.shouldNotify('child-1', 'com.game', stale, NOW)).toBe(false);
    expect(gate.shouldNotify('child-1', 'com.game', new Date(NOW - 30_000).toISOString(), NOW)).toBe(true);
  });

  it("vaqtsiz (eski ilova) va noto'g'ri vaqt bilan kelgan xabar o'tadi", () => {
    const gate = new GameNoticeGate();

    expect(gate.shouldNotify('child-1', 'com.a', undefined, NOW)).toBe(true);
    expect(gate.shouldNotify('child-1', 'com.b', 'not-a-date', NOW)).toBe(true);
  });
});
