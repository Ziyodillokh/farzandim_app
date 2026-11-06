import { roleHas } from '@/auth/permissions';
import type { CareSettings, CareSettingsView, CareStaffOption, Staff } from '@/data/contracts';
import { ServiceError } from '@/data/contracts';
import { type CareSettingsInput, careSettingsInputSchema } from '@/data/schemas/care';
import { parseOrThrow } from '@/data/schemas/validate';
import { type Actor, currentActor, latency, writeAudit } from '../context';
import { getTables, transact } from '../db';
import type { Tables } from '../tables';
import { nowLocalIso } from './comms-shared';

/**
 * Bola ovozi sozlamalari (kontrakt C).
 * - O'qish: `care.aggregate` YOKI `care.individual` (direktor, admin, psixolog).
 * - Yozish: psixolog (`care.individual`) yoki `staff.manage` (direktor). Admin — faqat o'qiydi.
 * - Auditda xodim ismi yo'q — faqat amal.
 */
const STAFF_ERROR = 'errors.form.staffInvalid';

/** Saqlangan yozuv yo'q bo'lganda qaytariladigan standart qiymatlar (`updatedAt: null`). */
export const DEFAULT_CARE_SETTINGS: CareSettings = {
  psychologistStaffId: null,
  psychologistDisplayName: null,
  deputyStaffId: null,
  deputyDisplayName: null,
  workDays: [1, 2, 3, 4, 5],
  workStart: '09:00',
  workEnd: '17:00',
  urgentSlaMinutes: 60,
  normalSlaHours: 24,
  updatedAt: null,
};

export function readCareSettings(t: Pick<Tables, 'careSettings'>): CareSettings {
  return t.careSettings ? { ...t.careSettings, workDays: [...t.careSettings.workDays] } : { ...DEFAULT_CARE_SETTINGS, workDays: [...DEFAULT_CARE_SETTINGS.workDays] };
}

function canReadSettings(actor: Actor): boolean {
  return roleHas(actor.role, 'care.aggregate') || roleHas(actor.role, 'care.individual');
}

function canWriteSettings(actor: Actor): boolean {
  return roleHas(actor.role, 'care.individual') || roleHas(actor.role, 'staff.manage');
}

/** Faol psixologlar (mas'ul va o'rinbosar faqat shulardan tanlanadi). */
export function staffOptions(t: Pick<Tables, 'staff'>): CareStaffOption[] {
  return t.staff
    .filter((s) => s.active && s.role === 'PSYCHOLOGIST')
    .map((s) => ({ id: s.id, fullName: s.fullName }))
    .sort((a, b) => a.fullName.localeCompare(b.fullName, 'uz'));
}

function view(t: Tables): CareSettingsView {
  return { ...readCareSettings(t), staffOptions: staffOptions(t) };
}

function isEligible(staff: readonly Staff[], id: string | null): boolean {
  return id === null || staff.some((s) => s.id === id && s.active && s.role === 'PSYCHOLOGIST');
}

export const careSettingsService = {
  async getSettings(): Promise<CareSettingsView> {
    await latency(40, 120);
    if (!canReadSettings(currentActor())) throw new ServiceError('FORBIDDEN', 'care.aggregate');
    return view(getTables());
  },

  async updateSettings(input: CareSettingsInput): Promise<CareSettingsView> {
    await latency();
    const actor = currentActor();
    if (!canWriteSettings(actor)) throw new ServiceError('FORBIDDEN', 'care.individual');
    const data = parseOrThrow(careSettingsInputSchema, input);
    return transact((t) => {
      if (!isEligible(t.staff, data.psychologistStaffId)) throw new ServiceError('VALIDATION', `psychologistStaffId: ${STAFF_ERROR}`);
      if (!isEligible(t.staff, data.deputyStaffId)) throw new ServiceError('VALIDATION', `deputyStaffId: ${STAFF_ERROR}`);
      t.careSettings = { ...data, workDays: [...data.workDays].sort((a, b) => a - b), updatedAt: nowLocalIso() };
      writeAudit(t, actor, 'CARE', 'care.settings.update', 'Bola ovozi: sozlamalar yangilandi');
      return view(t);
    });
  },
};
