// Ota-ona uchun o'quvchi bo'yicha maktab kontaktlari — sof funksiya (testlanadi).
//
// Kim ko'rinadi:
//  - CLASS      — o'quvchi sinfining rahbari (`SchoolClass.homeroomStaffId`);
//  - LEADERSHIP — direktor va ma'muriyat (ADMIN);
//  - SUPPORT    — psixolog(lar) — yozishma maxfiy, faqat psixologning o'zi o'qiydi;
//  - SUBJECT    — shu sinfga biriktirilgan o'qituvchilar (rahbardan tashqari).
// Navbatchi ro'yxatda yo'q. Faqat FAOL va panel hisobi bor xodim: hisobsiz
// xodimga yozilgan xabar hech kimga yetib bormaydi.

import { SchoolStaffRole } from '@prisma/client';

export type ContactGroup = 'CLASS' | 'LEADERSHIP' | 'SUPPORT' | 'SUBJECT';

export interface ContactStaff {
  id: string;
  fullName: string;
  role: SchoolStaffRole;
  position: string;
  active: boolean;
  hasAccount: boolean;
  classIds: readonly string[];
}

export interface ContactThreadInfo {
  threadId: string;
  unread: number;
  lastMessageAt: Date;
}

export interface ContactView {
  staffId: string;
  fullName: string;
  role: SchoolStaffRole;
  position: string;
  group: ContactGroup;
  threadId: string | null;
  unread: number;
  lastMessageAt: string | null;
}

const GROUP_ORDER: Record<ContactGroup, number> = { CLASS: 0, LEADERSHIP: 1, SUPPORT: 2, SUBJECT: 3 };
const ROLE_ORDER: Partial<Record<SchoolStaffRole, number>> = { DIRECTOR: 0, ADMIN: 1 };

/** Xodim shu o'quvchi uchun qaysi guruhda (yoki umuman ko'rinmaydi — `null`). */
export function contactGroup(staff: ContactStaff, classId: string | null, homeroomStaffId: string | null): ContactGroup | null {
  if (!staff.active || !staff.hasAccount) return null;
  if (homeroomStaffId && staff.id === homeroomStaffId) return 'CLASS';
  switch (staff.role) {
    case 'DIRECTOR':
    case 'ADMIN':
      return 'LEADERSHIP';
    case 'PSYCHOLOGIST':
      return 'SUPPORT';
    case 'TEACHER':
    case 'HOMEROOM':
      return classId && staff.classIds.includes(classId) ? 'SUBJECT' : null;
    default:
      return null;
  }
}

export function buildContacts(input: {
  classId: string | null;
  homeroomStaffId: string | null;
  staff: readonly ContactStaff[];
  threads: ReadonlyMap<string, ContactThreadInfo>;
}): ContactView[] {
  const rows = input.staff.flatMap((s) => {
    const group = contactGroup(s, input.classId, input.homeroomStaffId);
    if (!group) return [];
    const thread = input.threads.get(s.id);
    return [
      {
        staffId: s.id,
        fullName: s.fullName,
        role: s.role,
        position: s.position,
        group,
        threadId: thread?.threadId ?? null,
        unread: thread?.unread ?? 0,
        lastMessageAt: thread?.lastMessageAt.toISOString() ?? null,
      },
    ];
  });
  return rows.sort(
    (a, b) =>
      GROUP_ORDER[a.group] - GROUP_ORDER[b.group] ||
      (ROLE_ORDER[a.role] ?? 9) - (ROLE_ORDER[b.role] ?? 9) ||
      a.position.localeCompare(b.position, 'uz') ||
      a.fullName.localeCompare(b.fullName, 'uz'),
  );
}

/** Ro'yxat ko'rinishidagi qisqa matn (push / oldindan ko'rish). */
export function snippet(text: string, max = 120): string {
  const flat = text.replace(/\s+/g, ' ').trim();
  return flat.length <= max ? flat : `${flat.slice(0, max - 1).trimEnd()}…`;
}
