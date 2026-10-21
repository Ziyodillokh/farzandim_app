import { NextCode } from './insights';
import { fillL, NEXT_TEXTS, nextText, nextTextKey } from './texts';

const code = (patch: Partial<NextCode>): NextCode => ({
  kind: 'take_test',
  testType: 'career',
  externalId: null,
  mode: null,
  ...patch,
});

describe('kelajak texts', () => {
  it('fillL: har tilga o\'z qiymati, yo\'q bo\'lsa uz; noma\'lum o\'rin qoladi', () => {
    const text = { uz: 'Faoliyat: {activity} {x}', ru: 'Занятие: {activity}', en: 'Activity: {activity}' };
    expect(fillL(text, { activity: { uz: 'yasash', ru: 'поделка' } })).toEqual({
      uz: 'Faoliyat: yasash {x}',
      ru: 'Занятие: поделка',
      en: 'Activity: yasash',
    });
    expect(fillL({ uz: 'a {activity}' }, { activity: { uz: 'b' } })).toEqual({ uz: 'a b' });
  });

  it.each([
    [code({}), 'career'],
    [code({ testType: 'wellbeing' }), 'wellbeing'],
    [code({ kind: 'career_lab', testType: 'career_lab', externalId: 'PARVOZ-Q194', mode: 'try' }), 'career_lab_try'],
    [code({ kind: 'career_lab', testType: 'career_lab', externalId: 'PARVOZ-Q194', mode: 'deepen' }), 'career_lab_deepen'],
    [code({ kind: 'come_back', testType: null }), 'come_back'],
  ])('tavsiya kaliti: %j → %s', (next, key) => {
    expect(nextTextKey(next)).toBe(key);
  });

  it('nextText: Career Lab faoliyati nomi qo\'yiladi', () => {
    const text = nextText(
      code({ kind: 'career_lab', testType: 'career_lab', externalId: 'PARVOZ-Q194', mode: 'try' }),
      { uz: 'Biror narsa yasash', ru: 'Сделать что-то своими руками', en: 'Making something' },
    );
    expect(text.title).toEqual(NEXT_TEXTS.career_lab_try.title);
    expect(text.body.uz).toContain('Biror narsa yasash');
    expect(text.body.ru).toContain('Сделать что-то своими руками');
    expect(text.body.en).not.toContain('{activity}');
  });
});
