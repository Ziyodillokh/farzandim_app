// Oynali xatolar hisobi (xotirada): kalit bo'yicha oxirgi `windowMs` ichidagi xato urinishlar. Faqat XATOLAR
// sanaladi (muvaffaqiyatli urinish limitni yemaydi). Kalitlar soni cheklangan: to'lib ketsa eskirganlar, keyin
// eng eskilar tashlanadi. Qayta ishga tushganda hisob nolga tushadi.

export class SlidingFailureCounter {
  private readonly hits = new Map<string, number[]>();

  constructor(
    private readonly max: number,
    private readonly windowMs: number,
    private readonly maxKeys: number,
  ) {}

  /** Oynadagi xatolar soni `max`ga yetgan bo'lsa — keyingi urinishlar rad etiladi. */
  blocked(key: string, now: number): boolean {
    return this.recent(key, now).length >= this.max;
  }

  /** Blok qachon (soniya) yechiladi: eng oxirgi `max` ta xatodan eng eskisi oynadan chiqquncha; bloksiz bo'lsa 0. */
  retryAfterSeconds(key: string, now: number): number {
    const list = this.recent(key, now);
    if (list.length < this.max) return 0;
    const pivot = list[list.length - this.max]!;
    return Math.max(1, Math.ceil((pivot + this.windowMs - now) / 1000));
  }

  fail(key: string, now: number): void {
    const list = [...this.recent(key, now), now];
    this.hits.delete(key); // yangi yozuv Map oxiriga o'tadi (eng eskisi birinchi chiqadi)
    this.hits.set(key, list);
    if (this.hits.size > this.maxKeys) this.evict(now);
  }

  get size(): number {
    return this.hits.size;
  }

  private recent(key: string, now: number): number[] {
    const list = (this.hits.get(key) ?? []).filter((t) => now - t < this.windowMs);
    if (list.length === 0) this.hits.delete(key);
    else this.hits.set(key, list);
    return list;
  }

  private evict(now: number): void {
    for (const [key, list] of this.hits) {
      if (this.hits.size <= this.maxKeys) return;
      if (list.every((t) => now - t >= this.windowMs)) this.hits.delete(key);
    }
    for (const key of this.hits.keys()) {
      if (this.hits.size <= this.maxKeys) return;
      this.hits.delete(key);
    }
  }
}
