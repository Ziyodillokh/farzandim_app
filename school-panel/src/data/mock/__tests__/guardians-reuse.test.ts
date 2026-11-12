import { beforeEach, describe, expect, it } from 'vitest';

import { studentCreateFormSchema } from '@/data/schemas/students';
import { getTables } from '../db';
import { guardiansService, studentsService } from '../services/students';
import { freshDb, loginAs } from './helpers';

const pupil = (firstName: string, classId: string) => ({
  lastName: 'Karimov',
  firstName,
  middleName: '',
  gender: 'MALE' as const,
  birthDate: '2013-05-14',
  classId,
  device: 'NONE' as const,
});
const MOTHER = { fullName: 'Karimova Malika', phone: '+998 90 777 66 55', relation: 'MOTHER' as const };
const FATHER = { fullName: 'Karimov Akmal', phone: '+998 93 777 66 55', relation: 'FATHER' as const };

describe('ota-onalar: ikki ota-ona va telefon bo\'yicha birlashtirish', () => {
  let classId: string;

  beforeEach(() => {
    freshDb();
    loginAs('DIRECTOR');
    classId = getTables().classes[0]!.id;
  });

  it('yangi o\'quvchi ikki ota-ona bilan; aka-uka shu telefon bilan — mavjud yozuv bog\'lanadi', async () => {
    const before = getTables().guardians.length;

    const first = await studentsService.create({ ...pupil('Aziz', classId), guardians: [MOTHER, FATHER] });
    const sibling = await studentsService.create({ ...pupil('Laylo', classId), guardians: [{ ...MOTHER, fullName: 'Malika opa', phone: '+998907776655' }] });

    expect(first.guardianIds).toHaveLength(2);
    expect(first.reusedGuardians).toEqual([]);
    expect(sibling.reusedGuardians).toEqual([{ id: first.guardianIds[0], fullName: 'Karimova Malika' }]);
    expect(sibling.guardianIds).toEqual([first.guardianIds[0]]);
    expect(getTables().guardians.length).toBe(before + 2);
  });

  it('o\'quvchi sahifasidan: shu o\'quvchiga qayta — aniq xato; boshqasiga — mavjud bog\'lanadi', async () => {
    const first = await studentsService.create({ ...pupil('Aziz', classId), guardians: [MOTHER] });
    const second = await studentsService.create(pupil('Laylo', classId));

    await expect(guardiansService.addToStudent(first.id, MOTHER)).rejects.toMatchObject({ code: 'CONFLICT', detail: 'GUARDIAN_ALREADY_LINKED' });
    const added = await guardiansService.addToStudent(second.id, { ...MOTHER, fullName: 'Boshqa ism' });

    expect(added).toMatchObject({ id: first.guardianIds[0], fullName: 'Karimova Malika', reused: true });
  });

  it('CSV: kimligi va ikkinchi ota-ona ustunlari; faylning ichidagi aka-uka bitta ota-onaga', async () => {
    const className = getTables().classes[0]!.name;
    const result = await studentsService.importRows([
      ['Karimov', 'Aziz', '', className, 'M', '2013-05-14', MOTHER.fullName, MOTHER.phone, 'ona', FATHER.fullName, FATHER.phone, 'ota'],
      ['Karimova', 'Laylo', '', className, 'F', '2015-03-03', 'Malika', '+998907776655', 'onasi'],
    ]);

    expect(result).toMatchObject({ created: 2, skipped: [], reusedGuardians: 1 });
    const mother = getTables().guardians.find((g) => g.phone === MOTHER.phone);
    const father = getTables().guardians.find((g) => g.phone === FATHER.phone);
    expect(mother).toMatchObject({ relation: 'MOTHER', fullName: 'Karimova Malika' });
    expect(father).toMatchObject({ relation: 'FATHER' });
    expect(getTables().students.filter((s) => s.guardianIds.includes(mother!.id))).toHaveLength(2);
  });

  it('forma: bo\'sh qoralama o\'tkaziladi; faqat telefon — ism majburiy; ikki ota-onaga bir telefon — xato', () => {
    const base = { ...pupil('Aziz', classId) };
    const empty = { fullName: '', phone: '+998 ', relation: 'FATHER' as const };

    expect(studentCreateFormSchema.safeParse({ ...base, guardians: [empty, empty] }).success).toBe(true);
    const noName = studentCreateFormSchema.safeParse({ ...base, guardians: [{ ...MOTHER, fullName: '' }, empty] });
    expect(noName.error?.issues[0]).toMatchObject({ path: ['guardians', 0, 'fullName'], message: 'errors.form.required' });
    const same = studentCreateFormSchema.safeParse({ ...base, guardians: [MOTHER, { ...FATHER, phone: '+998907776655' }] });
    expect(same.error?.issues[0]).toMatchObject({ path: ['guardians', 1, 'phone'], message: 'errors.form.duplicatePhone' });
  });
});
