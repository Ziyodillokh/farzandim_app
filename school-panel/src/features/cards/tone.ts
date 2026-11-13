/** Kiosk ovoz signali: kirdi — bitta yuqori, ogohlantirish — ikkita, xato — ikkita past ton. */
export type ToneKind = 'ok' | 'warn' | 'fail';

const NOTES: Record<ToneKind, readonly number[]> = { ok: [880], warn: [660, 660], fail: [240, 190] };
const NOTE_S = 0.15;
const GAP_S = 0.18;

let context: AudioContext | null = null;

/** Brauzer ovozni faqat foydalanuvchi bosgandan keyin ruxsat beradi — «NFC'ni yoqish» tugmasida chaqiriladi. */
export function primeAudio(): void {
  try {
    context ??= new AudioContext();
    void context.resume();
  } catch {
    // Ovoz ixtiyoriy.
  }
}

export function playTone(kind: ToneKind): void {
  try {
    context ??= new AudioContext();
    const ctx = context;
    NOTES[kind].forEach((frequency, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      const start = ctx.currentTime + i * GAP_S;
      osc.frequency.value = frequency;
      gain.gain.setValueAtTime(0.25, start);
      gain.gain.exponentialRampToValueAtTime(0.001, start + NOTE_S);
      osc.connect(gain).connect(ctx.destination);
      osc.start(start);
      osc.stop(start + NOTE_S + 0.01);
    });
  } catch {
    // Ovoz ixtiyoriy: brauzer ruxsat bermasa jim davom etadi.
  }
}
