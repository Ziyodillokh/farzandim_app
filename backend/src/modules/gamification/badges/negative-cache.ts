/**
 * Kichik xotiradagi "yo'q" natijalar keshi (jarayon ichida, TTL bilan). Qimmat tekshiruv
 * (masalan mavzu o'zlashtirish oynasi) "hali yo'q" desa, shu kalit uchun TTL davomida
 * qayta so'ralmaydi. Xotira cheklangan: to'lganda avval muddati o'tganlari, so'ng eng
 * eskilari chiqariladi.
 */
export class NegativeCache {
  private readonly expiresAt = new Map<string, number>();

  constructor(
    private readonly ttlMs: number,
    private readonly maxEntries: number,
    private readonly clock: () => number = Date.now,
  ) {}

  has(key: string): boolean {
    const expiry = this.expiresAt.get(key);
    if (expiry === undefined) return false;
    if (expiry > this.clock()) return true;
    this.expiresAt.delete(key);
    return false;
  }

  add(key: string): void {
    this.expiresAt.delete(key); // yangilanganda tartib oxiriga o'tadi
    if (this.expiresAt.size >= this.maxEntries) this.evict();
    this.expiresAt.set(key, this.clock() + this.ttlMs);
  }

  delete(key: string): void {
    this.expiresAt.delete(key);
  }

  get size(): number {
    return this.expiresAt.size;
  }

  private evict(): void {
    const now = this.clock();
    for (const [key, expiry] of this.expiresAt) {
      if (expiry <= now) this.expiresAt.delete(key);
    }
    while (this.expiresAt.size >= this.maxEntries) {
      const oldest = this.expiresAt.keys().next();
      if (oldest.done) return;
      this.expiresAt.delete(oldest.value);
    }
  }
}
