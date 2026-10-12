import type { Announcement, PaymentReminder, Reminder, VerificationRequest } from '@/data/contracts';
import { Random } from '@/lib/rng';
import { addDays } from '../calendar';
import type { Family } from './people';
import { FIXED_STAFF } from './people';

const SCHOOL_AUDIENCE = { kind: 'SCHOOL' as const, classIds: [], guardianIds: [] };

export function buildAnnouncements(baseIso: string, guardiansTotal: number, seed: number): Announcement[] {
  const rng = new Random(seed + 11);
  const stats = (recipients: number, sent: boolean) => {
    if (!sent) return { recipients, delivered: 0, read: 0 };
    const delivered = Math.round(recipients * (0.9 + rng.float() * 0.08));
    return { recipients, delivered, read: Math.round(delivered * (0.62 + rng.float() * 0.3)) };
  };
  const day = (offset: number, time: string) => `${addDays(baseIso, offset)}T${time}:00`;
  const items: Array<Omit<Announcement, 'stats'> & { recipients: number }> = [
    {
      id: 'ann-1',
      title: 'Ota-onalar umumiy yig\'ilishi',
      body: 'Hurmatli ota-onalar! Shanba kuni soat 10:00 da maktab faollar zalida 1-chorak yakunlari bo\'yicha umumiy yig\'ilish bo\'ladi. Ishtirokingizni so\'raymiz.',
      audience: SCHOOL_AUDIENCE,
      priority: 'IMPORTANT',
      status: 'SENT',
      scheduledAt: null,
      sentAt: day(-2, '09:15'),
      byStaffId: FIXED_STAFF.director,
      recipients: guardiansTotal,
    },
    {
      id: 'ann-2',
      title: 'Kuzgi sport musobaqalari',
      body: '5–8-sinf o\'quvchilari uchun "Kuzgi startlar" musobaqasi juma kuni 14:00 da maktab stadionida. Sport kiyimini unutmang!',
      audience: { kind: 'CLASSES', classIds: ['cls-5a', 'cls-5b', 'cls-6a', 'cls-6b', 'cls-7a', 'cls-7b', 'cls-8a', 'cls-8b'], guardianIds: [] },
      priority: 'NORMAL',
      status: 'SENT',
      scheduledAt: null,
      sentAt: day(-4, '16:40'),
      byStaffId: FIXED_STAFF.admin,
      recipients: 330,
    },
    {
      id: 'ann-3',
      title: '7-A: matematika nazorat ishi',
      body: 'Ertaga 2-darsda "Kasrlar ustida amallar" mavzusida nazorat ishi bo\'ladi. Farzandingiz chizg\'ich va kalkulyatorsiz tayyorlansin.',
      audience: { kind: 'CLASSES', classIds: ['cls-7a'], guardianIds: [] },
      priority: 'NORMAL',
      status: 'SENT',
      scheduledAt: null,
      sentAt: day(-1, '18:05'),
      byStaffId: FIXED_STAFF.homeroom7a,
      recipients: 44,
    },
    {
      id: 'ann-4',
      title: 'Tibbiy ko\'rik',
      body: '1–4-sinf o\'quvchilari uchun rejali tibbiy ko\'rik keyingi hafta seshanba va chorshanba kunlari o\'tkaziladi.',
      audience: { kind: 'CLASSES', classIds: ['cls-1a', 'cls-1b', 'cls-2a', 'cls-2b', 'cls-3a', 'cls-3b', 'cls-4a', 'cls-4b'], guardianIds: [] },
      priority: 'NORMAL',
      status: 'SCHEDULED',
      scheduledAt: day(2, '08:00'),
      sentAt: null,
      byStaffId: FIXED_STAFF.admin,
      recipients: 310,
    },
    {
      id: 'ann-5',
      title: 'Maktab kutubxonasi yangi kitoblar oldi',
      body: 'Kutubxonamizga 120 dan ortiq yangi badiiy va ilmiy-ommabop kitoblar keldi. Farzandlaringizni kitob o\'qishga undang!',
      audience: SCHOOL_AUDIENCE,
      priority: 'NORMAL',
      status: 'DRAFT',
      scheduledAt: null,
      sentAt: null,
      byStaffId: FIXED_STAFF.admin,
      recipients: guardiansTotal,
    },
    {
      id: 'ann-6',
      title: 'Dars jadvalidagi o\'zgarish',
      body: 'Ertadan boshlab 9-B sinfida fizika darsi 3-soatga ko\'chirildi.',
      audience: { kind: 'CLASSES', classIds: ['cls-9b'], guardianIds: [] },
      priority: 'IMPORTANT',
      status: 'SENT',
      scheduledAt: null,
      sentAt: day(-6, '12:30'),
      byStaffId: FIXED_STAFF.admin,
      recipients: 46,
    },
  ];
  return items.map(({ recipients, ...a }) => ({ ...a, stats: stats(recipients, a.status === 'SENT') }));
}

export function buildReminders(baseIso: string): Reminder[] {
  const at = (offset: number, time: string) => `${addDays(baseIso, offset)}T${time}:00`;
  return [
    { id: 'rem-1', kind: 'MEETING', title: 'Ota-onalar yig\'ilishi', body: '1-chorak yakunlari. Shanba, 10:00, faollar zali.', audience: SCHOOL_AUDIENCE, sendAt: at(4, '09:00'), repeat: 'NONE', active: true, byStaffId: FIXED_STAFF.director },
    { id: 'rem-2', kind: 'EXAM', title: '9–11-sinflar: chorak nazorat ishlari', body: 'Nazorat ishlari jadvali Parvoz ilovasida e\'lon qilindi.', audience: { kind: 'CLASSES', classIds: ['cls-9a', 'cls-9b', 'cls-10a', 'cls-10b', 'cls-11a', 'cls-11b'], guardianIds: [] }, sendAt: at(6, '18:00'), repeat: 'NONE', active: true, byStaffId: FIXED_STAFF.admin },
    { id: 'rem-3', kind: 'HOLIDAY', title: 'Kuzgi ta\'til', body: 'Kuzgi ta\'til 2-noyabrdan 9-noyabrgacha. Darslar 10-noyabr kuni boshlanadi.', audience: SCHOOL_AUDIENCE, sendAt: at(18, '17:00'), repeat: 'NONE', active: true, byStaffId: FIXED_STAFF.admin },
    { id: 'rem-4', kind: 'EVENT', title: 'Kitobxonlik tanlovi', body: '"Yosh kitobxon" maktab bosqichi — ishtirokchilar ro\'yxatini sinf rahbaridan oling.', audience: SCHOOL_AUDIENCE, sendAt: at(9, '15:00'), repeat: 'NONE', active: true, byStaffId: FIXED_STAFF.admin },
    { id: 'rem-5', kind: 'ANNOUNCEMENT', title: 'Haftalik maktab e\'lonlari', body: 'Har dushanba — haftaning muhim tadbirlari.', audience: SCHOOL_AUDIENCE, sendAt: at(7, '08:30'), repeat: 'WEEKLY', active: true, byStaffId: FIXED_STAFF.admin },
    { id: 'rem-6', kind: 'SCHEDULE_CHANGE', title: '2-smena: qisqartirilgan kun', body: 'Juma kuni 2-smenada darslar 35 daqiqadan o\'tadi.', audience: { kind: 'CLASSES', classIds: ['cls-1a', 'cls-1b', 'cls-2a', 'cls-2b', 'cls-3a', 'cls-3b', 'cls-4a', 'cls-4b'], guardianIds: [] }, sendAt: at(3, '12:00'), repeat: 'NONE', active: false, byStaffId: FIXED_STAFF.admin },
  ];
}

/** Har oila uchun keyingi to'lov eslatmasi sanasi (maktab tasdiqlagan). */
export function buildPayments(families: Family[], baseIso: string, seed: number): PaymentReminder[] {
  const rng = new Random(seed + 13);
  const firstOfNextMonth = (() => {
    const [y, m] = baseIso.split('-').map(Number);
    const d = new Date(y ?? 2026, m ?? 1, 5);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-05`;
  })();
  return families.map((family, i) => {
    const r = rng.float();
    const prepaidMonths = r < 0.62 ? 0 : r < 0.8 ? 1 : r < 0.92 ? 3 : 4;
    const nextDate = prepaidMonths === 0 ? firstOfNextMonth : addMonths(firstOfNextMonth, prepaidMonths);
    return {
      id: `pay-${i + 1}`,
      guardianId: family.primaryGuardianId,
      studentIds: family.studentIds,
      nextDate,
      prepaidMonths,
      paused: rng.bool(0.03),
      history: [
        { at: `${addDays(baseIso, -40)}T10:00:00`, byStaffId: FIXED_STAFF.admin, action: 'CREATED', note: 'O\'quv yili boshida yaratildi' },
        ...(prepaidMonths > 0
          ? [{ at: `${addDays(baseIso, -12)}T11:20:00`, byStaffId: FIXED_STAFF.admin, action: 'SHIFTED' as const, note: `${prepaidMonths} oy oldindan to'lov (buxgalteriya tasdig'i)` }]
          : []),
      ],
    };
  });
}

function addMonths(iso: string, months: number): string {
  const [y, m, d] = iso.split('-').map(Number);
  const date = new Date(y ?? 2026, (m ?? 1) - 1 + months, d ?? 1);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

export function buildVerifications(payments: PaymentReminder[], baseIso: string): VerificationRequest[] {
  const candidates = payments.filter((p) => p.prepaidMonths === 0).slice(0, 4);
  const messages = [
    'Assalomu alaykum! Biz sentabrda 4 oylik to\'lovni oldindan qilganmiz, lekin eslatma keldi. Tekshirib bera olasizmi?',
    'Ikki farzandim uchun bitta eslatma kelishi kerak edi, ikkita keldi.',
    'To\'lovni kecha bank orqali qildim, chek bor. Eslatmani to\'xtatib qo\'ying, iltimos.',
    'Eslatma sanasini oyning 10-sanasiga ko\'chirish mumkinmi? Maosh shu kuni tushadi.',
  ];
  return candidates.map((p, i) => ({
    id: `ver-${i + 1}`,
    guardianId: p.guardianId,
    paymentReminderId: p.id,
    message: messages[i] ?? messages[0]!,
    createdAt: `${addDays(baseIso, -i)}T${String(9 + i).padStart(2, '0')}:1${i}:00`,
    status: i === 3 ? 'ANSWERED' : 'OPEN',
    answer: i === 3 ? 'Albatta, eslatma sanasi har oyning 10-sanasiga ko\'chirildi.' : null,
    answeredByStaffId: i === 3 ? FIXED_STAFF.admin : null,
    answeredAt: i === 3 ? `${addDays(baseIso, -2)}T15:00:00` : null,
  }));
}
