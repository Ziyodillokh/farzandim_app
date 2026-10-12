import { assignAllPortraits } from '@/lib/staff-avatar';
import { PREF_PREFIX } from '@/lib/prefs';
import { generateSeed } from './seed';
import type { DbSnapshot, Tables } from './tables';

/**
 * MockDb — bitta localStorage kaliti, versiyalangan sxema.
 *
 * Har o'zgarish (`transact`) AVVAL xotiradagi eng yangi holatni o'qiydi, keyin
 * yozadi — kiosk va panel ikki tabda ochiq bo'lsa ham bir-birini o'chirmaydi.
 * Boshqa tab yozganda `storage` hodisasi keladi → obunachilar (React Query)
 * ma'lumotni yangilaydi.
 */
export const SCHEMA_VERSION = 1;
export const SEED = 20261012;
const STORAGE_KEY = `${PREF_PREFIX}db:v${SCHEMA_VERSION}`;
const MAX_AUDIT = 1500;

type Listener = () => void;

let snapshot: DbSnapshot | null = null;
let memoryOnly = false;
const listeners = new Set<Listener>();
let storageWarning: (() => void) | null = null;

function hasStorage(): boolean {
  return typeof window !== 'undefined' && !memoryOnly;
}

function readStored(): DbSnapshot | null {
  if (!hasStorage()) return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as DbSnapshot;
    return parsed.schemaVersion === SCHEMA_VERSION ? withPortraits(parsed) : null;
  } catch {
    return null;
  }
}

/** Yumshoq migratsiya: portretlar qo'shilishidan oldingi saqlangan bazaga portret beriladi. */
function withPortraits(db: DbSnapshot): DbSnapshot {
  if (db.tables.staff.every((s) => s.portrait)) return db;
  return { ...db, tables: { ...db.tables, staff: assignAllPortraits(db.tables.staff) } };
}

function persist(next: DbSnapshot): void {
  if (!hasStorage()) return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  } catch {
    memoryOnly = true;
    storageWarning?.();
  }
}

function createFresh(): DbSnapshot {
  const now = new Date();
  return {
    schemaVersion: SCHEMA_VERSION,
    seed: SEED,
    generatedAt: now.toISOString(),
    baseDate: now.toISOString().slice(0, 10),
    tables: generateSeed(SEED, now),
  };
}

/** Joriy holat (birinchi chaqiruvda yuklanadi yoki yaratiladi). */
export function getDb(): DbSnapshot {
  if (snapshot) return snapshot;
  const stored = readStored();
  if (stored) {
    snapshot = stored;
  } else {
    snapshot = createFresh();
    persist(snapshot);
  }
  return snapshot;
}

export function getTables(): Tables {
  return getDb().tables;
}

function trimAudit(tables: Tables): void {
  if (tables.audit.length > MAX_AUDIT) tables.audit.splice(0, tables.audit.length - MAX_AUDIT);
}

/**
 * O'zgarish: `fn` jadvallarning NUSXASI ustida ishlaydi (asl holat o'zgarmaydi),
 * natija saqlanadi va obunachilar xabardor qilinadi.
 */
export function transact<R>(fn: (tables: Tables) => R): R {
  const latest = readStored() ?? getDb();
  const draft: DbSnapshot = { ...latest, tables: structuredClone(latest.tables) };
  const result = fn(draft.tables);
  trimAudit(draft.tables);
  snapshot = draft;
  persist(draft);
  emit();
  return result;
}

export function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function emit(): void {
  for (const listener of listeners) listener();
}

/** Boshqa tab yozganini kuzatish (bir marta ulanadi). */
let crossTabBound = false;
export function bindCrossTabSync(): void {
  if (crossTabBound || typeof window === 'undefined') return;
  crossTabBound = true;
  window.addEventListener('storage', (event) => {
    if (event.key !== STORAGE_KEY) return;
    const stored = readStored();
    if (stored) {
      snapshot = stored;
      emit();
    }
  });
}

export function onStorageFull(handler: () => void): void {
  storageWarning = handler;
}

/** Demo ma'lumotlarni boshlang'ich holatga qaytarish. */
export function resetDb(): DbSnapshot {
  snapshot = createFresh();
  memoryOnly = false;
  persist(snapshot);
  emit();
  return snapshot;
}

/** Faqat testlar uchun — xotiradagi holatni tozalash. */
export function __resetForTests(next?: DbSnapshot): void {
  snapshot = next ?? null;
}
