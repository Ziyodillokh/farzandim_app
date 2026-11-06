// Kalit bo'yicha ketma-ketlik (bitta jarayon ichida): bir xil kalitli amallar navbat bilan bajariladi, boshqa
// kalitlar parallel. Urinish limiti "tekshir -> bajar -> hisobla" ketma-ketligi bo'linmasligi uchun kerak:
// aks holda bir vaqtdagi 300 so'rov hammasi hisob yangilanmasdan limitdan o'tib ketadi. Backend bitta instance
// (`FailureLimiter` bilan bir xil taxmin). Bir necha kalit saralangan tartibda olinadi — deadlock bo'lmaydi.

export class KeyedMutex {
  private readonly tails = new Map<string, Promise<void>>();

  async runExclusive<T>(keys: readonly string[], run: () => Promise<T>): Promise<T> {
    const releases: Array<() => void> = [];
    try {
      for (const key of [...new Set(keys)].sort()) releases.push(await this.acquire(key));
      return await run();
    } finally {
      for (const release of releases.reverse()) release();
    }
  }

  /** Hozir kutayotgan yoki bajarilayotgan kalitlar soni (testlar uchun). */
  get activeKeys(): number {
    return this.tails.size;
  }

  private async acquire(key: string): Promise<() => void> {
    const previous = this.tails.get(key) ?? Promise.resolve();
    let release!: () => void;
    const current = new Promise<void>((resolve) => {
      release = resolve;
    });
    const tail = previous.then(() => current);
    this.tails.set(key, tail);
    await previous;
    return () => {
      release();
      if (this.tails.get(key) === tail) this.tails.delete(key);
    };
  }
}
