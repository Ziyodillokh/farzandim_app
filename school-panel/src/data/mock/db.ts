import { assignAllPortraits } from '@/lib/staff-avatar';
import { PREF_PREFIX } from '@/lib/prefs';
import { toIsoDate } from './calendar';
import { clockNow } from './clock';
import { buildPsychSeed } from './psych/seed';
import { generateSeed } from './seed';
import { buildCareSettings } from './seed/care';
import { buildDeputyPsychologist } from './seed/people';
import { buildActivity, CLOSED_WEEKS } from './seed/learning';
import { buildSubmissions, buildWrittenAssignments } from './seed/homework';
import { buildAccess } from './seed/access';
import { buildNotifications } from './seed/notifications';
import { buildTimetables } from './seed/timetable';
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

function readRaw(): DbSnapshot | null {
  if (!hasStorage()) return null;
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as DbSnapshot;
    return parsed.schemaVersion === SCHEMA_VERSION ? parsed : null;
  } catch {
    return null;
  }
}

/** O'qish + yumshoq migratsiyalar (har `transact` da chaqiriladi — qadamlar arzon va idempotent). */
function readStored(): DbSnapshot | null {
  const raw = readRaw();
  return raw ? migrate(raw) : null;
}

/**
 * Yumshoq migratsiyalar: yangi jadval qo'shilganda eski foydalanuvchi ma'lumoti
 * o'chmaydi. Har qadam o'zgarish bo'lmasa AYNAN o'sha obyektni qaytaradi.
 */
type Migration = (db: DbSnapshot) => DbSnapshot;

/** Portretlar qo'shilishidan oldingi bazaga portret beriladi. */
function withPortraits(db: DbSnapshot): DbSnapshot {
  if (db.tables.staff.every((s) => s.portrait)) return db;
  return { ...db, tables: { ...db.tables, staff: assignAllPortraits(db.tables.staff) } };
}

/** Psixologik testlar jadvallari (saqlangan sinf va o'quvchilardan). */
function withAssessments(db: DbSnapshot): DbSnapshot {
  if (db.tables.psychHistory) return db;
  return { ...db, tables: { ...db.tables, ...buildPsychSeed(db.tables, db.baseDate, db.seed) } };
}

/** Bildirishnomalar va o'quvchi eslatmalari. */
function withStaffTables(db: DbSnapshot): DbSnapshot {
  if (db.tables.notifications && db.tables.studentNotes) return db;
  return {
    ...db,
    tables: {
      ...db.tables,
      notifications: db.tables.notifications ?? buildNotifications(db.tables.careRequests),
      studentNotes: db.tables.studentNotes ?? [],
    },
  };
}

/** Growth faolligi: 6 yakunlangan hafta + davom etayotgan hafta (avvalgi saqlangan bazada 6 hafta edi). */
function withActivityWeeks(db: DbSnapshot): DbSnapshot {
  if (new Set(db.tables.activity.map((a) => a.weekStart)).size > CLOSED_WEEKS) return db;
  const sizes = new Map<string, number>();
  for (const s of db.tables.students) sizes.set(s.classId, (sizes.get(s.classId) ?? 0) + 1);
  return { ...db, tables: { ...db.tables, activity: buildActivity(db.tables.classes, sizes, db.baseDate) } };
}

/** Dars jadvali: avval saqlangan bazada sinflar uchun demo jadval yaratiladi. */
function withTimetables(db: DbSnapshot): DbSnapshot {
  if (db.tables.timetables) return db;
  return { ...db, tables: { ...db.tables, timetables: buildTimetables(db.tables.classes, db.tables.shifts) } };
}

/** Yozma vazifalar: demo vazifalar (yo'q bo'lsa) va o'quvchilar ishlari jadvali. */
function withHomework(db: DbSnapshot): DbSnapshot {
  if (db.tables.submissions) return db;
  const known = new Set(db.tables.assignments.map((a) => a.id));
  const assignments = [...db.tables.assignments, ...buildWrittenAssignments(db.baseDate).filter((a) => !known.has(a.id))];
  return { ...db, tables: { ...db.tables, assignments, submissions: buildSubmissions(assignments, db.tables.students, db.baseDate) } };
}

/**
 * Bola ovozi sozlamalari: avval saqlangan bazada demo sozlamalar va ikkinchi psixolog (o'rinbosar) qo'shiladi.
 * Foydalanuvchi sozlamani o'zi saqlagan bo'lsa (`careSettings !== undefined`) tegilmaydi.
 */
function withCareSettings(db: DbSnapshot): DbSnapshot {
  if (db.tables.careSettings !== undefined) return db;
  const deputy = buildDeputyPsychologist();
  const staff = db.tables.staff.some((s) => s.id === deputy.id) ? db.tables.staff : assignAllPortraits([...db.tables.staff, deputy]);
  return { ...db, tables: { ...db.tables, staff, careSettings: buildCareSettings(db.baseDate) } };
}

/**
 * Bola ↔ psixolog yozishmasi: avval saqlangan murojaatlarga bolaning birinchi xabari (id `initial`) va
 * holat vaqtlari qo'shiladi. Holati NEW bo'lmagan murojaat «ochilgan» deb hisoblanadi (xodim uni allaqachon ko'rgan).
 */
function withCareThread(db: DbSnapshot): DbSnapshot {
  if (db.tables.careRequests.every((r) => Array.isArray(r.messages))) return db;
  const careRequests = db.tables.careRequests.map((r) => {
    if (Array.isArray(r.messages)) return r;
    const seen = r.status !== 'NEW';
    const opened = seen ? (r.notes[0]?.at ?? r.createdAt) : null;
    return {
      ...r,
      messages: [{ id: 'initial', author: 'CHILD' as const, staffId: null, text: r.message, createdAt: r.createdAt, readByStaffAt: opened }],
      assignedStaffId: db.tables.careSettings?.psychologistStaffId ?? null,
      openedAt: opened,
      openedByStaffId: null,
      repliedAt: null,
      resolvedAt: r.status === 'RESOLVED' ? (r.notes.at(-1)?.at ?? r.createdAt) : null,
      escalatedAt: null,
      lastMessageAt: r.createdAt,
    };
  });
  return { ...db, tables: { ...db.tables, careRequests } };
}

/**
 * Kirish (5-bosqich): avval saqlangan bazada ulanish, kirish ma'lumotlari, kodlar va so'rovlar jadvallari (demo ma'lumot bilan)
 * hamda ularga mos xodim bildirishnomalari qo'shiladi.
 */
function withAccess(db: DbSnapshot): DbSnapshot {
  if (db.tables.access) return db;
  const { access, notifications } = buildAccess({
    students: db.tables.students,
    guardians: db.tables.guardians,
    classes: db.tables.classes,
    baseIso: db.baseDate,
    seed: db.seed,
  });
  const current = db.tables.notifications ?? [];
  const known = new Set(current.map((n) => n.id));
  return { ...db, tables: { ...db.tables, access, notifications: [...current, ...notifications.filter((n) => !known.has(n.id))] } };
}

const MIGRATIONS: readonly Migration[] = [
  withPortraits,
  withAssessments,
  withStaffTables,
  withActivityWeeks,
  withTimetables,
  withHomework,
  withCareSettings,
  withCareThread,
  withAccess,
];

export function migrate(db: DbSnapshot): DbSnapshot {
  return MIGRATIONS.reduce((current, step) => step(current), db);
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

/** Yangi demo baza — demo soati kuniga bog'langan (ssenariy kechqurun ham "bugun" ertalab). */
export function createFreshSnapshot(anchor: Date = clockNow()): DbSnapshot {
  return {
    schemaVersion: SCHEMA_VERSION,
    seed: SEED,
    generatedAt: new Date().toISOString(),
    baseDate: toIsoDate(anchor),
    tables: generateSeed(SEED, anchor),
  };
}

function createFresh(): DbSnapshot {
  return createFreshSnapshot();
}

/** Joriy holat (birinchi chaqiruvda yuklanadi yoki yaratiladi). */
export function getDb(): DbSnapshot {
  if (snapshot) return snapshot;
  const raw = readRaw();
  if (raw) {
    snapshot = migrate(raw);
    if (snapshot !== raw) persist(snapshot);
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
