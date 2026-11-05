import {
  fillTopicText,
  gradeRangeError,
  isValidTopicKey,
  parseTopicText,
  TOPIC_KEY_MAX,
  TOPIC_TITLE_MAX,
} from './topic-input';

describe('isValidTopicKey', () => {
  it.each(['kasrlar', 'oddiy-kasrlar', 'a1', 'grade-5-fractions', '5'])('"%s" — yaroqli', (key) => {
    expect(isValidTopicKey(key)).toBe(true);
  });

  it.each(['', 'Kasrlar', 'kasr lar', 'kasr_lar', '-kasr', 'kasr-', 'kasr--lar', "o'zbek", 'kasrlar!', 42, null])(
    '%p — yaroqsiz',
    (key) => {
      expect(isValidTopicKey(key)).toBe(false);
    },
  );

  it('uzunlik chegarasi', () => {
    expect(isValidTopicKey('a'.repeat(TOPIC_KEY_MAX))).toBe(true);
    expect(isValidTopicKey('a'.repeat(TOPIC_KEY_MAX + 1))).toBe(false);
  });
});

describe('parseTopicText', () => {
  it('faqat uz yetarli; bo\'sh ru / en tushiriladi, matn qirqiladi', () => {
    expect(parseTopicText({ uz: '  Kasrlar ', ru: '', en: '   ' }, 'title', TOPIC_TITLE_MAX)).toEqual({
      ok: true,
      value: { uz: 'Kasrlar' },
    });
    expect(parseTopicText({ uz: 'Kasrlar', ru: 'Дроби', en: 'Fractions' }, 'title', TOPIC_TITLE_MAX)).toEqual({
      ok: true,
      value: { uz: 'Kasrlar', ru: 'Дроби', en: 'Fractions' },
    });
  });

  it.each([
    [null, 'obyekt'],
    ['Kasrlar', 'obyekt'],
    [[], 'obyekt'],
    [{}, 'title.uz'],
    [{ uz: '   ' }, 'title.uz'],
    [{ ru: 'Дроби' }, 'title.uz'],
    [{ uz: 5 }, 'title.uz'],
    [{ uz: 'a', ru: 7 }, 'title.ru'],
    [{ uz: 'a', fr: 'b' }, 'noma\'lum til'],
    [{ uz: 'x'.repeat(TOPIC_TITLE_MAX + 1) }, 'uzun'],
  ])('%p — xato (%s)', (value, fragment) => {
    const result = parseTopicText(value, 'title', TOPIC_TITLE_MAX);
    expect(result.ok).toBe(false);
    expect((result as { error: string }).error).toContain(fragment);
  });
});

describe('fillTopicText', () => {
  it('yetishmayotgan tillar uz bilan to\'ldiriladi', () => {
    expect(fillTopicText({ uz: 'Kasrlar', en: 'Fractions' })).toEqual({
      uz: 'Kasrlar',
      ru: 'Kasrlar',
      en: 'Fractions',
    });
  });
});

describe('gradeRangeError', () => {
  it('to\'g\'ri oraliq — null', () => {
    expect(gradeRangeError(1, 11)).toBeNull();
    expect(gradeRangeError(5, 5)).toBeNull();
  });

  it.each([
    [0, 5],
    [5, 12],
    [7, 5],
    [1.5, 4],
    [Number.NaN, 4],
  ])('%p..%p — xato', (min, max) => {
    expect(gradeRangeError(min, max)).not.toBeNull();
  });
});
