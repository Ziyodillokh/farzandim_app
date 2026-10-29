/**
 * Deterministik tasodifiy sonlar — seed bir xil bo'lsa ma'lumot ham har safar
 * bir xil (demo "tiklash" bir xil holatga qaytadi, testlar barqaror).
 */

/** mulberry32 — kichik, tez, sifati demo uchun yetarli. */
export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Satrdan 32-bit xesh (FNV-1a). */
export function hashString(value: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < value.length; i++) {
    h ^= value.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/** Bir nechta qiymatdan barqaror [0,1) son: `unitHash('stu-1', '2026-10-12')`. */
export function unitHash(...parts: Array<string | number>): number {
  // murmur3 fmix32: FNV-1a ning yuqori bitlari oxirgi belgilardagi farqqa sust
  // javob beradi (o'xshash kalitlar — tor oraliq), aralashtirish tekis taqsimot beradi.
  let h = hashString(parts.join('|'));
  h ^= h >>> 16;
  h = Math.imul(h, 0x85ebca6b);
  h ^= h >>> 13;
  h = Math.imul(h, 0xc2b2ae35);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967296;
}

export class Random {
  private readonly next: () => number;

  constructor(seed: number) {
    this.next = mulberry32(seed);
  }

  float(): number {
    return this.next();
  }

  int(min: number, max: number): number {
    return min + Math.floor(this.next() * (max - min + 1));
  }

  bool(probability = 0.5): boolean {
    return this.next() < probability;
  }

  pick<T>(items: readonly T[]): T {
    if (items.length === 0) throw new Error('Random.pick: bo\'sh ro\'yxat');
    return items[Math.floor(this.next() * items.length)] as T;
  }

  /** Tartibni aralashtirilgan yangi massiv (asl massiv o'zgarmaydi). */
  shuffle<T>(items: readonly T[]): T[] {
    const copy = [...items];
    for (let i = copy.length - 1; i > 0; i--) {
      const j = Math.floor(this.next() * (i + 1));
      [copy[i], copy[j]] = [copy[j] as T, copy[i] as T];
    }
    return copy;
  }
}
