import type { Guardian, ParentAuthor, ParentThreadStatus, ParentTopic, Student } from '@/data/contracts';
import { addDays } from '../calendar';
import { FIXED_STAFF } from './people';

/**
 * Demo: ota-onalar xodimlarga yozgan xabarlar (Parvoz Parents → "Maktab bilan bog'lanish").
 * Har demo xodimga (sinf rahbari 7-A, direktor, admin, psixolog) hayotiy holatlar: javob
 * kutilayotgan, javob berilgan va hal qilingan yozishmalar. Deterministik (bir xil baza → bir xil natija).
 */

export type MockParentMessage = { id: string; author: ParentAuthor; topic: ParentTopic | null; text: string; createdAt: string };

export type MockParentThread = {
  id: string;
  staffId: string;
  studentId: string;
  guardianId: string;
  status: ParentThreadStatus;
  staffReadAt: string | null;
  parentReadAt: string | null;
  createdAt: string;
  messages: MockParentMessage[];
};

type Script = {
  staffId: string;
  /** Qaysi o'quvchi: 7-A dan (sinf rahbari uchun) yoki butun maktabdan, tartib raqami bilan. */
  pick: { classId?: string; index: number };
  status: ParentThreadStatus;
  /** Xodim oxirgi marta qachon o'qigan (xabar indeksi; null — umuman o'qimagan). */
  staffReadUpTo: number | null;
  messages: { author: ParentAuthor; topic?: ParentTopic; text: string; day: number; time: string }[];
};

const SCRIPTS: readonly Script[] = [
  {
    staffId: FIXED_STAFF.homeroom7a,
    pick: { classId: 'cls-7a', index: 0 },
    status: 'OPEN',
    staffReadUpTo: null,
    messages: [
      {
        author: 'PARENT',
        topic: 'ABSENCE',
        text: "Assalomu alaykum, ustoz. Farzandim bugun isitmasi chiqib qoldi, maktabga kela olmaydi. Shifokorga boryapmiz, ma'lumotnoma olib kelamiz.",
        day: 0,
        time: '07:32',
      },
    ],
  },
  {
    staffId: FIXED_STAFF.homeroom7a,
    pick: { classId: 'cls-7a', index: 3 },
    status: 'OPEN',
    staffReadUpTo: 0,
    messages: [
      { author: 'PARENT', topic: 'HOMEWORK', text: 'Ustoz, «Mening Vatanim» inshosini qachongacha topshirish kerak? Farzandim kitobini maktabda qoldiribdi.', day: -1, time: '19:05' },
      { author: 'STAFF', text: 'Vaalaykum assalom! Inshoni payshanbagacha topshirsa bo\'ladi. Kitobini ertaga sinfda olib ketsin.', day: -1, time: '20:12' },
      { author: 'PARENT', text: 'Katta rahmat, ustoz!', day: -1, time: '20:15' },
    ],
  },
  {
    staffId: FIXED_STAFF.homeroom7a,
    pick: { classId: 'cls-7a', index: 6 },
    status: 'RESOLVED',
    staffReadUpTo: 1,
    messages: [
      { author: 'PARENT', topic: 'MEETING', text: "Ustoz, farzandimning o'zlashtirishi haqida yuzma-yuz gaplashsak bo'ladimi? Juma kuni darsdan keyin bo'shman.", day: -4, time: '18:40' },
      { author: 'STAFF', text: "Albatta. Juma, soat 13:30 da 214-xonada kutaman.", day: -4, time: '19:02' },
    ],
  },
  {
    staffId: FIXED_STAFF.director,
    pick: { index: 12 },
    status: 'OPEN',
    staffReadUpTo: null,
    messages: [
      {
        author: 'PARENT',
        topic: 'SUGGESTION',
        text: "Hurmatli direktor! Maktab oldidagi yo'lda ertalab tirbandlik bo'lyapti. Bolalarni tushirish uchun alohida joy belgilansa, xavfsizroq bo'lardi.",
        day: 0,
        time: '08:47',
      },
    ],
  },
  {
    staffId: FIXED_STAFF.director,
    pick: { index: 40 },
    status: 'RESOLVED',
    staffReadUpTo: 1,
    messages: [
      { author: 'PARENT', topic: 'THANKS', text: "Maktabdagi kuzgi bayram juda chiroyli o'tdi. O'qituvchilarga rahmat!", day: -3, time: '17:20' },
      { author: 'STAFF', text: "Iliq so'zlaringiz uchun rahmat! Jamoaga albatta yetkazaman.", day: -3, time: '18:05' },
    ],
  },
  {
    staffId: FIXED_STAFF.admin,
    pick: { index: 25 },
    status: 'OPEN',
    staffReadUpTo: null,
    messages: [
      { author: 'PARENT', topic: 'PAYMENT', text: "Noyabr oyi uchun to'lovni Click orqali qildim. Chek raqami 48213 — tekshirib bera olasizmi?", day: 0, time: '09:15' },
    ],
  },
  {
    staffId: FIXED_STAFF.admin,
    pick: { index: 31 },
    status: 'OPEN',
    staffReadUpTo: 1,
    messages: [
      { author: 'PARENT', topic: 'DOCUMENT', text: "Farzandim uchun «maktabda o'qiydi» degan ma'lumotnoma kerak edi (bog'chaga topshirish uchun).", day: -2, time: '10:30' },
      { author: 'STAFF', text: "Ertaga soat 10:00 dan keyin kotibiyatdan olishingiz mumkin. Pasportingizni olib keling.", day: -2, time: '11:05' },
    ],
  },
  {
    staffId: FIXED_STAFF.psychologist,
    pick: { index: 18 },
    status: 'OPEN',
    staffReadUpTo: null,
    messages: [
      {
        author: 'PARENT',
        topic: 'WELLBEING',
        text: "Assalomu alaykum. Farzandim so'nggi ikki haftada uyda kam gapiradi, maktabga borgisi kelmayapti. Maslahatlashsak bo'ladimi?",
        day: 0,
        time: '06:58',
      },
    ],
  },
];

export function buildParentThreads(input: { students: readonly Student[]; guardians: readonly Guardian[]; baseIso: string }): MockParentThread[] {
  const active = input.students.filter((s) => !s.archived && s.guardianIds.length > 0);
  const linkedGuardian = (s: Student) => input.guardians.find((g) => s.guardianIds.includes(g.id) && g.linkStatus === 'LINKED') ?? input.guardians.find((g) => g.id === s.guardianIds[0]);
  const at = (day: number, time: string) => `${addDays(input.baseIso, day)}T${time}:00`;
  const used = new Set<string>();

  return SCRIPTS.flatMap((script, n) => {
    const pool = script.pick.classId ? active.filter((s) => s.classId === script.pick.classId) : active;
    const candidates = pool.slice(script.pick.index).concat(pool.slice(0, script.pick.index));
    const student = candidates.find((s) => !used.has(s.id));
    const guardian = student && linkedGuardian(student);
    if (!student || !guardian) return [];
    used.add(student.id);
    const messages = script.messages.map((m, i) => ({ id: `pm-${n + 1}-${i + 1}`, author: m.author, topic: m.topic ?? null, text: m.text, createdAt: at(m.day, m.time) }));
    const staffRead = script.staffReadUpTo === null ? null : messages[script.staffReadUpTo]?.createdAt ?? null;
    const lastStaff = [...messages].reverse().find((m) => m.author === 'STAFF');
    return [
      {
        id: `pth-${n + 1}`,
        staffId: script.staffId,
        studentId: student.id,
        guardianId: guardian.id,
        status: script.status,
        staffReadAt: staffRead,
        // Ota-ona xodim javobini o'qigan (javobdan keyin yozgan yoki darhol ko'rgan).
        parentReadAt: lastStaff ? lastStaff.createdAt : null,
        createdAt: messages[0]!.createdAt,
        messages,
      },
    ];
  });
}
