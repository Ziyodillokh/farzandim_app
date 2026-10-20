// Tayyor xabar shablonlari — panel `comms-templates.ts` bilan bir xil (matn —
// ota-onaga boradigan o'zbekcha mazmun). Kvadrat qavsdagi joylar (`[sana]`)
// yuborishdan oldin to'ldiriladi. To'lov shabloni hech qachon "qarzdorsiz"
// demaydi — faqat maktab tasdiqlagan sana.

import type { MessagePriority } from './comms.schemas';

export const TEMPLATE_IDS = ['meeting', 'exam', 'event', 'holiday', 'payment', 'schedule', 'health'] as const;
export type TemplateId = (typeof TEMPLATE_IDS)[number];

export interface MessageTemplate {
  id: TemplateId;
  priority: MessagePriority;
  title: string;
  body: string;
}

export const MESSAGE_TEMPLATES: readonly MessageTemplate[] = [
  {
    id: 'meeting',
    priority: 'IMPORTANT',
    title: "Ota-onalar yig'ilishi",
    body: "Hurmatli ota-onalar! [sana] kuni soat [vaqt] da maktab faollar zalida ota-onalar yig'ilishi bo'lib o'tadi. Kun tartibi: [mavzu]. Ishtirokingizni so'raymiz.",
  },
  {
    id: 'exam',
    priority: 'NORMAL',
    title: 'Nazorat ishi',
    body: "[sana] kuni [fan] fanidan nazorat ishi bo'ladi. Mavzu: [mavzu]. Farzandingiz yaxshi dam olib, kerakli o'quv qurollari bilan kelsin.",
  },
  {
    id: 'event',
    priority: 'NORMAL',
    title: 'Maktab tadbiri',
    body: '[sana] kuni soat [vaqt] da maktabimizda "[tadbir nomi]" tadbiri o\'tkaziladi. Barcha ota-onalarni tadbirga taklif qilamiz!',
  },
  {
    id: 'holiday',
    priority: 'IMPORTANT',
    title: "Ta'til haqida",
    body: "Hurmatli ota-onalar! Ta'til [boshlanish] dan [tugash] gacha davom etadi. Darslar [sana] kuni odatdagi jadval bo'yicha boshlanadi.",
  },
  {
    id: 'payment',
    priority: 'NORMAL',
    title: "To'lov eslatmasi",
    body: "Hurmatli ota-ona! Maktab tasdiqlagan jadvalga ko'ra navbatdagi to'lov sanasi — [sana]. Agar to'lovni oldindan amalga oshirgan bo'lsangiz, ushbu eslatmani e'tiborsiz qoldiring yoki ilovada \"Tekshirish\" tugmasini bosing.",
  },
  {
    id: 'schedule',
    priority: 'IMPORTANT',
    title: "Dars jadvalidagi o'zgarish",
    body: "[sana] dan boshlab [sinf] sinfida [fan] darsi [yangi vaqt] ga ko'chirildi. Iltimos, farzandingizni shunga ko'ra tayyorlang.",
  },
  {
    id: 'health',
    priority: 'NORMAL',
    title: "Tibbiy ko'rik",
    body: "[sana] kuni [sinflar] o'quvchilari uchun rejali tibbiy ko'rik o'tkaziladi. Farzandingizning tibbiy daftarchasini olib kelishini so'raymiz.",
  },
];
