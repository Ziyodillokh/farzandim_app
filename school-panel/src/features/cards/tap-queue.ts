import { PREF_PREFIX } from '@/lib/prefs';

/**
 * Kiosk oflayn navbati: internet uzilganda tegish shu qurilmada saqlanadi va internet qaytgach
 * yuboriladi (server 12 soatgacha qabul qiladi). Faqat shu brauzer uchun qulaylik —
 * saqlab bo'lmasa (yopiq rejim) navbat xotirada qoladi.
 */
const QUEUE_KEY = `${PREF_PREFIX}kiosk-card-queue`;
const KIOSK_ID_KEY = `${PREF_PREFIX}kiosk-id`;
export const MAX_QUEUE = 300;

export type QueuedTap = { uid?: string; url?: string; kioskId: string; tappedAt: string };

let memoryQueue: QueuedTap[] = [];
let memoryKioskId: string | null = null;

function storage(): Storage | null {
  try {
    return typeof window === 'undefined' ? null : window.localStorage;
  } catch {
    return null;
  }
}

export function loadQueue(): QueuedTap[] {
  try {
    const raw = storage()?.getItem(QUEUE_KEY);
    const parsed: unknown = raw ? JSON.parse(raw) : memoryQueue;
    return Array.isArray(parsed) ? (parsed as QueuedTap[]) : [];
  } catch {
    return memoryQueue;
  }
}

export function saveQueue(queue: readonly QueuedTap[]): void {
  memoryQueue = queue.slice(-MAX_QUEUE);
  try {
    storage()?.setItem(QUEUE_KEY, JSON.stringify(memoryQueue));
  } catch {
    // Saqlab bo'lmadi (yopiq rejim / to'lgan) — navbat xotirada qoladi.
  }
}

export function enqueueTap(tap: QueuedTap): QueuedTap[] {
  const next = [...loadQueue(), tap].slice(-MAX_QUEUE);
  saveQueue(next);
  return next;
}

/** Shu kiosk qurilmasi belgisi ("bir o'qigichda 3 soniyada 2 karta" qoidasi uchun). */
export function kioskId(): string {
  const make = () => `kiosk-${Math.random().toString(36).slice(2, 10)}${Date.now().toString(36)}`;
  try {
    const s = storage();
    const existing = s?.getItem(KIOSK_ID_KEY);
    if (existing) return existing;
    memoryKioskId ??= make();
    s?.setItem(KIOSK_ID_KEY, memoryKioskId);
  } catch {
    memoryKioskId ??= make();
  }
  return memoryKioskId;
}
