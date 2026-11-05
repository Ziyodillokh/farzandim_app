// Bir vaqtda ishlayotgan yuklashlar chegarasi (jarayon ichida): har so'rov 5 x 8 MB gacha rasmni
// xotirada ushlaydi (+ EXIF tozalash nusxasi). Chegaradan oshsa — 429, klient `requestId` bilan qayta urinadi.

export const MAX_CONCURRENT_UPLOADS = 6;

export class InFlightGate {
  private active = 0;

  constructor(private readonly max: number) {}

  tryEnter(): boolean {
    if (this.active >= this.max) return false;
    this.active += 1;
    return true;
  }

  leave(): void {
    this.active = Math.max(0, this.active - 1);
  }

  get inFlight(): number {
    return this.active;
  }
}
