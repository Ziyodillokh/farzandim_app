import type { Holiday, School, Shift } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { holidayInputSchema, schoolProfileSchema, type HolidayInput, type SchoolProfileInput } from '@/data/schemas/school';
import { parseOrThrow } from '@/data/schemas/validate';
import { assertCan, currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';

/** Logo — data URL (≤ 256 px, SVG/PNG/JPEG/WebP). */
const LOGO_PATTERN = /^data:image\/(png|jpeg|webp|svg\+xml);base64,/;
const MAX_LOGO_BYTES = 350_000;

export const schoolService = {
  /** Maktab profili — ochiq (kirish sahifasidagi nom va logo uchun ham). */
  async get(): Promise<{ school: School; shifts: Shift[]; holidays: Holiday[] }> {
    await latency(30, 80);
    const t = getTables();
    return { school: t.school, shifts: t.shifts, holidays: t.holidays };
  },

  async updateProfile(input: SchoolProfileInput): Promise<School> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'settings.manage');
    const data = parseOrThrow(schoolProfileSchema, input);
    return transact((t) => {
      const before = { ...t.school };
      t.school = { ...t.school, ...data };
      writeAudit(t, actor, 'SETTINGS', 'school.update', 'Maktab profili yangilandi', t.school.id, before, t.school, {});
      return t.school;
    });
  },

  async setLogo(logo: string | null): Promise<School> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'settings.manage');
    if (logo !== null && (!LOGO_PATTERN.test(logo) || logo.length > MAX_LOGO_BYTES)) {
      throw new ServiceError('VALIDATION', 'logo');
    }
    return transact((t) => {
      t.school = { ...t.school, logo };
      writeAudit(t, actor, 'SETTINGS', logo ? 'school.logo' : 'school.logoRemove', logo ? 'Maktab logosi yangilandi' : 'Maktab logosi olib tashlandi', t.school.id, null, null, {});
      return t.school;
    });
  },

  async addHoliday(input: HolidayInput): Promise<Holiday> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'schoolMode.manage');
    const data = parseOrThrow(holidayInputSchema, input);
    return transact((t) => {
      if (t.holidays.some((h) => h.date === data.date)) throw new ServiceError('CONFLICT', data.date);
      const holiday: Holiday = { id: `hol-${data.date}`, ...data };
      t.holidays = [...t.holidays, holiday].sort((a, b) => a.date.localeCompare(b.date));
      writeAudit(t, actor, 'SCHOOL_MODE', 'holiday.create', `Bayram kuni qo'shildi: ${data.date} — ${data.name}`, holiday.id, null, null, {
        date: data.date,
        name: data.name,
      });
      return holiday;
    });
  },

  async removeHoliday(id: string): Promise<void> {
    await latency();
    const actor = currentActor();
    assertCan(actor, 'schoolMode.manage');
    transact((t) => {
      const holiday = t.holidays.find((h) => h.id === id);
      if (!holiday) throw new ServiceError('NOT_FOUND', id);
      t.holidays = t.holidays.filter((h) => h.id !== id);
      writeAudit(t, actor, 'SCHOOL_MODE', 'holiday.delete', `Bayram kuni olib tashlandi: ${holiday.date}`, id, null, null, { date: holiday.date });
    });
  },
};

/** Logoni brauzerda 256 px gacha kichraytirish (PNG data URL). */
export async function resizeLogo(file: File, size = 256): Promise<string> {
  if (file.type === 'image/svg+xml' && file.size < MAX_LOGO_BYTES * 0.7) {
    const text = await file.text();
    return `data:image/svg+xml;base64,${btoa(unescape(encodeURIComponent(text)))}`;
  }
  const url = URL.createObjectURL(file);
  try {
    const image = await new Promise<HTMLImageElement>((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = reject;
      img.src = url;
    });
    const scale = Math.min(1, size / Math.max(image.width, image.height));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(image.width * scale));
    canvas.height = Math.max(1, Math.round(image.height * scale));
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('canvas');
    ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/png');
  } finally {
    URL.revokeObjectURL(url);
  }
}
