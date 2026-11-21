// Ota-ona maktabga ulanganda (8 belgili vasiy kodi, 6 raqamli kod yoki xodim tasdig'i) farzandi hali hech qaysi
// o'quvchiga bog'lanmagan bo'lsa — ism bo'yicha avtomatik moslash. Faqat bir ma'noli holatda: o'quvchining ismi
// ota-onaning bo'sh (faol o'quvchiga ulanmagan) farzandlaridan AYNAN BITTASI ismiga mos kelsa. Shubhali holatda
// (mos yo'q yoki bir nechta) hech narsa qilinmaydi — ota-ona ilovada bir bosishda moslaydi. Maqsad: begona
// bolaning qurilmasiga maktab ma'lumoti (davomat, School Mode) tushmasin.

import { Prisma } from '@prisma/client';
import { toAsciiSlug } from '../../modules/child-auth/child-credentials.helpers';
import { settleConfirmedLink, tryLinkChildToStudent } from './link-core';

type Tx = Prisma.TransactionClient;

const NAME_SLUG_MAX = 40;
/** Erkalash qo'shimchalari: "Azizjon" = "Aziz", "Mohinurxon" = "Mohinur" (qolgan qismi kamida 3 harf). */
const AFFECTIONATE_SUFFIXES = ['jon', 'xon'] as const;
const MIN_NAME = 3;

/** Ism bo'lagining solishtirish kaliti: lotin/kirill, tutuq belgilari, katta-kichik harf va «-jon/-xon» farqsiz. */
export function nameKey(part: string): string {
  const slug = toAsciiSlug(part, NAME_SLUG_MAX);
  const suffix = AFFECTIONATE_SUFFIXES.find((s) => slug.endsWith(s) && slug.length - s.length >= MIN_NAME);
  return suffix ? slug.slice(0, -suffix.length) : slug;
}

/** Bola ismidagi biror so'z o'quvchining ismiga aniq mos keladimi ("Азиза Каримова" ↔ "Aziza"). */
export function namesMatch(childName: string, studentFirstName: string): boolean {
  const target = nameKey(studentFirstName);
  if (target.length < MIN_NAME) return false;
  return childName.split(/[\s-]+/).some((part) => nameKey(part) === target);
}

/**
 * O'quvchi bo'sh bo'lsa, ota-onaning ismi mos keladigan YAGONA bo'sh farzandini bog'laydi. Qaytadi: bog'langan
 * bola yoki `null` (moslik yo'q / bir nechta / to'siq bor).
 */
export async function matchOwnChildByName(
  tx: Tx,
  ctx: { student: { id: string; firstName: string; childId: string | null }; childIds: readonly string[]; now: Date },
): Promise<string | null> {
  const { student, childIds, now } = ctx;
  if (student.childId || childIds.length === 0) return null;
  const [children, enrolled] = await Promise.all([
    tx.child.findMany({ where: { id: { in: [...childIds] } }, select: { id: true, name: true, parentId: true } }),
    tx.schoolStudent.findMany({
      where: { childId: { in: [...childIds] }, archived: false, school: { status: 'ACTIVE' } },
      select: { childId: true },
    }),
  ]);
  const busy = new Set(enrolled.map((s) => s.childId));
  const matches = children.filter((c) => !busy.has(c.id) && namesMatch(c.name, student.firstName));
  if (matches.length !== 1) return null;
  const child = matches[0]!;
  if ((await tryLinkChildToStudent(tx, student, child)) !== 'LINKED') return null;
  await settleConfirmedLink(tx, student.id, child.id, now);
  return child.id;
}
