import type { IsoDate, School, Staff } from '@/data/contracts';
import { fromIsoDate, toIsoDate, toLocalIso } from './calendar';
import { clockNow } from './clock';
import { getDb, resetDb, transact } from './db';
import { academicYearStart } from './seed/structure';
import type { DbSnapshot, Tables } from './tables';

/**
 * Demo ma'lumotlari "bugun"ga bog'langan (nisbiy sanalar, bugungi so'rovlar).
 * Baza boshqa kunda yaratilgan bo'lsa (masalan, kecha ochilgan demo) — demo
 * soati kuniga qayta yaratiladi, maktab brendi va xodim rasmlari saqlanadi.
 */
export type FreshnessResult = 'OK' | 'REGENERATED';

const DAY_MS = 86_400_000;

/** Saqlanadigan maktab maydonlari (brend va sozlamalar). */
type Brand = Pick<School, 'name' | 'shortName' | 'city' | 'logo' | 'phone' | 'address' | 'lateAfterMinutes'>;

/** Ikki sana orasidagi to'liq kunlar (yo'nalishsiz). */
export function daysBetween(a: IsoDate, b: IsoDate): number {
  return Math.round(Math.abs(fromIsoDate(a).getTime() - fromIsoDate(b).getTime()) / DAY_MS);
}

/** Baza demo soati kuniga mos kelmaydimi (kun yoki o'quv yili o'zgargan). */
export function needsRegeneration(db: Pick<DbSnapshot, 'baseDate'>, anchor: Date): boolean {
  const today = toIsoDate(anchor);
  if (daysBetween(db.baseDate, today) >= 1) return true;
  return academicYearStart(fromIsoDate(db.baseDate)) !== academicYearStart(anchor);
}

function brandOf(school: School): Brand {
  return {
    name: school.name,
    shortName: school.shortName,
    city: school.city,
    logo: school.logo,
    phone: school.phone,
    address: school.address,
    lateAfterMinutes: school.lateAfterMinutes,
  };
}

function withStaffMedia(fresh: readonly Staff[], previous: readonly Staff[]): Staff[] {
  const byId = new Map(previous.map((s) => [s.id, s]));
  return fresh.map((s) => {
    const old = byId.get(s.id);
    if (!old) return s;
    return {
      ...s,
      ...(old.photo !== undefined ? { photo: old.photo } : {}),
      ...(old.portrait ? { portrait: old.portrait } : {}),
    };
  });
}

/** Yangi jadvallarga eski bazadan saqlanadiganlarni ko'chiradi (sof funksiya). */
export function carryOver(previous: Tables, fresh: Tables): Pick<Tables, 'school' | 'staff' | 'psychTests' | 'psychTemplateState'> {
  return {
    school: { ...fresh.school, ...brandOf(previous.school) },
    staff: withStaffMedia(fresh.staff, previous.staff),
    psychTests: previous.psychTests.filter((test) => test.source !== 'TEMPLATE'),
    psychTemplateState: { ...previous.psychTemplateState },
  };
}

/**
 * Kerak bo'lsa bazani demo soati kuniga qayta yaratadi (`createFreshSnapshot(clockNow())`
 * — `resetDb` orqali), brend, rasmlar va maktabning o'z testlarini saqlaydi.
 */
export function ensureDemoFresh(): FreshnessResult {
  const db = getDb();
  if (!needsRegeneration(db, clockNow())) return 'OK';
  const previous = db.tables;
  const fromDate = db.baseDate;
  resetDb();
  transact((t) => {
    const kept = carryOver(previous, t);
    t.school = kept.school;
    t.staff = kept.staff;
    t.psychTests = kept.psychTests;
    t.psychTemplateState = kept.psychTemplateState;
    t.audit.push({
      id: `aud-fresh-${Date.now()}`,
      at: toLocalIso(clockNow()),
      actorId: 'system',
      actorName: 'Demo',
      module: 'SETTINGS',
      action: 'demo.regenerated',
      entityId: null,
      summary: `Demo ma'lumotlar yangi kunga moslandi (${fromDate} → ${toIsoDate(clockNow())})`,
      before: null,
      after: null,
    });
  });
  return 'REGENERATED';
}
