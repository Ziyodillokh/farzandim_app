// Taklif kodini tanlab topishga qarshi: faqat XATO urinishlar sanaladi
// (muvaffaqiyatli kiritish limitni yemaydi). Backend bitta instance — xotira
// yetarli; qayta ishga tushganda hisob nolga tushadi (oyna qisqa).

export class FailureLimiter {
  private readonly failures = new Map<string, number[]>();

  constructor(
    private readonly max: number,
    private readonly windowMs: number,
  ) {}

  blocked(key: string, now = Date.now()): boolean {
    return this.recent(key, now).length >= this.max;
  }

  fail(key: string, now = Date.now()): void {
    this.failures.set(key, [...this.recent(key, now), now]);
  }

  private recent(key: string, now: number): number[] {
    const list = (this.failures.get(key) ?? []).filter((t) => now - t < this.windowMs);
    if (list.length === 0) this.failures.delete(key);
    else this.failures.set(key, list);
    return list;
  }
}
