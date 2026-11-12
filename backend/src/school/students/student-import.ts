// CSV import qatorlarini tekshirish (sof funksiya): sinf nomi, sana va
// takrorlar. Ustunlar: [familiya, ism, otasining ismi, sinf (7-A), jinsi
// (M/F), tug'ilgan sana, ota-ona, telefon, kimligi, 2-ota-ona, 2-telefon,
// 2-kimligi]. Oxirgi to'rttasi ixtiyoriy (eski 8 ustunli fayl ham ishlaydi);
// kimligi bo'sh yoki noma'lum bo'lsa — «Boshqa».

import { GuardianData, StudentCreate, studentCreateSchema } from './students.schemas';

export interface ImportCandidate {
  row: number;
  data: StudentCreate;
}

export interface ImportSkip {
  row: number;
  reason: string;
}

/** "7a", "7 - A", "7-а" → "7-A" (sinf nomi bilan solishtirish uchun). */
export function normalizeClassName(name: string): string {
  const compact = name.toUpperCase().replace(/\s+/g, '');
  const match = /^(\d{1,2})-?(.+)$/.exec(compact);
  return match ? `${match[1]}-${match[2]}` : compact;
}

/** `YYYY-MM-DD` yoki `DD.MM.YYYY` / `DD/MM/YYYY` → ISO; mavjud bo'lmagan sana → null. */
export function toIsoDate(value: string): string | null {
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  const local = /^(\d{1,2})[./](\d{1,2})[./](\d{4})$/.exec(value);
  const [y, m, d] = iso
    ? [Number(iso[1]), Number(iso[2]), Number(iso[3])]
    : local
      ? [Number(local[3]), Number(local[2]), Number(local[1])]
      : [NaN, NaN, NaN];
  const date = new Date(Date.UTC(y, m - 1, d));
  if (Number.isNaN(date.getTime()) || date.getUTCMonth() !== m - 1 || date.getUTCDate() !== d) return null;
  return date.toISOString().slice(0, 10);
}

/** Takrorni aniqlash kaliti: familiya + ism + tug'ilgan sana. */
export const duplicateKey = (s: { lastName: string; firstName: string; birthDate: string }) =>
  `${s.lastName}|${s.firstName}|${s.birthDate}`.toLowerCase().replace(/[ʻʼ’‘`´']/g, "'");

const FEMALE = /^(f|q|ж|female)/i;

type Relation = GuardianData['relation'];

const RELATIONS: ReadonlyArray<[RegExp, Relation]> = [
  [/^(ona|onasi|мать|мама|mother|mom)/i, 'MOTHER'],
  [/^(ota|otasi|отец|папа|father|dad)/i, 'FATHER'],
  [/^(buvi|bobo|buvisi|bobosi|бабушка|дедушка|grand)/i, 'GRANDPARENT'],
];

/** «Ona», «otasi», «бабушка», «MOTHER» → munosabat; bo'sh / noma'lum → `OTHER`. */
export function parseRelation(value: string): Relation {
  const text = value.trim();
  return RELATIONS.find(([re]) => re.test(text))?.[1] ?? 'OTHER';
}

/** Ism va telefon ikkalasi bo'lsa — ota-ona (aks holda yo'q). */
function guardianOf(name: string, phone: string, relation: string) {
  return name && phone ? [{ fullName: name, phone, relation: parseRelation(relation) }] : [];
}

export function parseImportRows(
  rows: string[][],
  classIdByName: ReadonlyMap<string, string>,
  existingKeys: ReadonlySet<string>,
): { candidates: ImportCandidate[]; skipped: ImportSkip[] } {
  const candidates: ImportCandidate[] = [];
  const skipped: ImportSkip[] = [];
  const seen = new Set(existingKeys);
  rows.forEach((cells, i) => {
    const row = i + 1;
    const [
      lastName = '',
      firstName = '',
      middleName = '',
      className = '',
      gender = '',
      birth = '',
      guardianName = '',
      phone = '',
      relation = '',
      guardian2Name = '',
      phone2 = '',
      relation2 = '',
    ] = cells.map((c) => c.trim());
    if (!cells.some((c) => c.trim())) return;
    const classId = classIdByName.get(normalizeClassName(className));
    if (!classId) return skipped.push({ row, reason: `class:${className}` });
    const birthDate = toIsoDate(birth);
    if (!birthDate) return skipped.push({ row, reason: 'birthDate' });
    const parsed = studentCreateSchema.safeParse({
      lastName,
      firstName,
      middleName,
      classId,
      gender: FEMALE.test(gender) ? 'FEMALE' : 'MALE',
      birthDate,
      device: 'NONE',
      guardians: [...guardianOf(guardianName, phone, relation), ...guardianOf(guardian2Name, phone2, relation2)],
    });
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      return skipped.push({ row, reason: issue ? `${issue.path.join('.')}: ${issue.message}` : 'invalid' });
    }
    const key = duplicateKey(parsed.data);
    if (seen.has(key)) return skipped.push({ row, reason: 'duplicate' });
    seen.add(key);
    candidates.push({ row, data: parsed.data });
  });
  return { candidates, skipped };
}
