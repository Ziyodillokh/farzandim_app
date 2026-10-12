import { roleHas } from '@/auth/permissions';
import { DEMO_ACCOUNTS } from '@/auth/demo-accounts';
import type { RoleKey } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';

/** Avatar uchun minimal ma'lumot (ro'yxatlar, menyular, login kartochkalari). */
export type StaffAvatarInfo = { id: string; fullName: string; role: RoleKey; photo: string | null; portrait: string | null };
export type MyProfile = StaffAvatarInfo & { position: string; phone: string; email: string; username: string | null };

/** Faqat raster rasm (SVG emas — ichida skript bo'lishi mumkin), ~90 KB gacha. */
const PHOTO_PATTERN = /^data:image\/(jpeg|webp|png);base64,[A-Za-z0-9+/=]+$/;
export const MAX_PHOTO_CHARS = 120_000;

function toInfo(s: { id: string; fullName: string; role: RoleKey; photo?: string | null; portrait?: string }): StaffAvatarInfo {
  return { id: s.id, fullName: s.fullName, role: s.role, photo: s.photo ?? null, portrait: s.portrait ?? null };
}

export const profileService = {
  /** Kirgan foydalanuvchining o'z profili. */
  async me(): Promise<MyProfile> {
    await latency(30, 80);
    const actor = currentActor();
    const s = getTables().staff.find((x) => x.id === actor.staffId);
    if (!s) throw new ServiceError('NOT_FOUND', actor.staffId);
    return { ...toInfo(s), position: s.position, phone: s.phone, email: s.email, username: s.username };
  },

  /** Barcha xodimlar avatarlari (id → ma'lumot). Faqat kirgan foydalanuvchiga. */
  async avatars(): Promise<Record<string, StaffAvatarInfo>> {
    await latency(20, 60);
    currentActor();
    return Object.fromEntries(getTables().staff.map((s) => [s.id, toInfo(s)]));
  },

  /** Login sahifasi uchun — sessiyasiz, faqat demo hisoblar. */
  async demoProfiles(): Promise<Record<string, StaffAvatarInfo>> {
    const ids = new Set(DEMO_ACCOUNTS.map((a) => a.staffId));
    return Object.fromEntries(getTables().staff.filter((s) => ids.has(s.id)).map((s) => [s.id, toInfo(s)]));
  },

  /** Rasm yuklash/olib tashlash: o'zi yoki `staff.manage` (direktor). */
  async setPhoto(staffId: string, photo: string | null): Promise<StaffAvatarInfo> {
    await latency();
    const actor = currentActor();
    if (actor.staffId !== staffId && !roleHas(actor.role, 'staff.manage')) throw new ServiceError('FORBIDDEN', 'staff.photo');
    if (photo !== null && (!PHOTO_PATTERN.test(photo) || photo.length > MAX_PHOTO_CHARS)) {
      throw new ServiceError('VALIDATION', 'profile.photo.invalid');
    }
    return transact((t) => {
      const s = t.staff.find((x) => x.id === staffId);
      if (!s) throw new ServiceError('NOT_FOUND', staffId);
      const next = { ...s, photo };
      t.staff = t.staff.map((x) => (x.id === staffId ? next : x));
      // Auditda rasm baytlari yo'q — faqat fakt.
      writeAudit(t, actor, 'STAFF', photo ? 'staff.photo' : 'staff.photoRemove', `Xodim rasmi ${photo ? 'yangilandi' : 'olib tashlandi'}: ${s.fullName}`, staffId);
      return toInfo(next);
    });
  },
};
