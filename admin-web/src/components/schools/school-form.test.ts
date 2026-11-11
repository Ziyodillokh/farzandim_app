import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  credentialsText,
  emptySchoolForm,
  hasErrors,
  suggestSchoolCode,
  toCreatePayload,
  validateSchoolForm,
} from './school-form';

test('suggestSchoolCode: lotin, kirill va tutuq belgilari', () => {
  assert.equal(suggestSchoolCode('24-maktab, Chilonzor'), '24-maktab-chilonzor');
  assert.equal(suggestSchoolCode('Parvoz QA maktabi'), 'parvoz-qa-maktabi');
  assert.equal(suggestSchoolCode("Oʻzbekiston gʻuncha's"), 'ozbekiston-gunchas');
  assert.equal(suggestSchoolCode('Тошкент 5-мактаб'), 'toshkent-5-maktab');
  assert.equal(suggestSchoolCode('  !!  '), '');
  assert.ok(suggestSchoolCode('a'.repeat(60)).length <= 40);
  assert.ok(!suggestSchoolCode(`${'a'.repeat(39)} b`).endsWith('-'));
});

test("validateSchoolForm: bo'sh forma — majburiy maydonlar", () => {
  const errors = validateSchoolForm(emptySchoolForm());
  assert.deepEqual(Object.keys(errors).sort(), ['city', 'code', 'directorName', 'name']);
});

test("validateSchoolForm + toCreatePayload: to'g'ri forma", () => {
  const form = {
    name: ' 14-maktab ',
    shortName: '',
    city: 'Toshkent',
    code: 'Parvoz-14',
    directorName: 'Karimov Akmal',
    directorUsername: 'Direktor',
  };
  assert.equal(hasErrors(validateSchoolForm(form)), false);
  assert.deepEqual(toCreatePayload(form), {
    code: 'parvoz-14',
    name: '14-maktab',
    city: 'Toshkent',
    director: { fullName: 'Karimov Akmal', username: 'direktor' },
  });
  assert.ok(validateSchoolForm({ ...form, shortName: 'x'.repeat(13) }).shortName);
  assert.ok(validateSchoolForm({ ...form, directorUsername: 'ab' }).directorUsername);
  assert.ok(validateSchoolForm({ ...form, code: '14 maktab' }).code);
});

test('credentialsText: manzil, kod, login va parol', () => {
  const text = credentialsText({
    schoolName: '14-maktab',
    schoolCode: 'parvoz-14',
    username: 'direktor',
    temporaryPassword: 'Ab3dEf7hJk9m',
  });
  assert.match(text, /farzandimedu\.uz\/maktab\//);
  assert.match(text, /Maktab kodi: parvoz-14/);
  assert.match(text, /Login: direktor/);
  assert.match(text, /Vaqtinchalik parol: Ab3dEf7hJk9m/);
});

test('formatDate: Toshkent kuni', async () => {
  const { formatDate } = await import('./school-format');
  assert.equal(formatDate('2026-11-10T20:30:00.000Z'), '11-noy 2026');
  assert.equal(formatDate(null), '—');
  assert.equal(formatDate('buzuq'), '—');
});
