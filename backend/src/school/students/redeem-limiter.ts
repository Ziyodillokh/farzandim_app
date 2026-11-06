// Taklif kodini tanlab topishga qarshi: faqat XATO urinishlar sanaladi
// (muvaffaqiyatli kiritish limitni yemaydi). Backend bitta instance — xotira
// yetarli; qayta ishga tushganda hisob nolga tushadi (oyna qisqa).

export class FailureLimiter {
  private readonly failures = new Map<string, number[]>();
  private lastSweepAt = 0;

  constructor(
    private readonly max: number,
    private readonly windowMs: number,
  ) {}

  blocked(key: string, now = Date.now()): boolean {
    return this.recent(key, now).length >= this.max;
  }

  fail(key: string, now = Date.now()): void {
    this.failures.set(key, [...this.recent(key, now), now]);
    // Bir marta xato qilib ketgan kalitlar (turli IP / profil) xotirada to'planib qolmasin: oynada bir marta tozalanadi.
    if (now - this.lastSweepAt >= this.windowMs) this.sweep(now);
  }

  /** Blok tugashigacha qolgan vaqt (ms); bloklanmagan bo'lsa 0. */
  retryAfterMs(key: string, now = Date.now()): number {
    const list = this.recent(key, now);
    if (list.length < this.max) return 0;
    // Hisob `max` dan pastga tushadigan lahza: shu xatolardan eng eskisi oynadan chiqqanda.
    const releasing = list[list.length - this.max]!;
    return Math.max(0, releasing + this.windowMs - now);
  }

  /** Barcha hisobni tozalaydi (testlar uchun). */
  clear(): void {
    this.failures.clear();
  }

  private sweep(now: number): void {
    this.lastSweepAt = now;
    for (const key of [...this.failures.keys()]) this.recent(key, now);
  }

  /** Hisobdagi kalitlar soni (testlar uchun). */
  get size(): number {
    return this.failures.size;
  }

  private recent(key: string, now: number): number[] {
    const list = (this.failures.get(key) ?? []).filter((t) => now - t < this.windowMs);
    if (list.length === 0) this.failures.delete(key);
    else this.failures.set(key, list);
    return list;
  }
}
