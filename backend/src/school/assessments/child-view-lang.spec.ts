import { SCHOOL_CHILD_EN } from '../common/child-en.data';
import { childLang, pick } from './child-view';
import { PSYCH_TEMPLATES } from './psych/templates';

describe('bola tili (maktab matnlari)', () => {
  it('en — tayyor matn inglizcha, xodim matni o\'zbekcha qoladi', () => {
    expect(childLang('en')).toBe('en');
    expect(childLang('de')).toBe('uz');
    expect(pick({ uz: 'Xotira', ru: 'Память' }, 'en')).toBe('Memory');
    expect(pick({ uz: 'Xodim yozgan savol', ru: 'Вопрос' }, 'en')).toBe('Xodim yozgan savol');
    expect(pick({ uz: 'Xotira', ru: 'Память' }, 'ru')).toBe('Память');
  });

  it('shablonlarning har bir matni inglizchaga ega', () => {
    const missing: string[] = [];
    const walk = (v: unknown): void => {
      if (Array.isArray(v)) return v.forEach(walk);
      if (!v || typeof v !== 'object') return;
      const o = v as Record<string, unknown>;
      if (typeof o.uz === 'string' && typeof o.ru === 'string') {
        if (o.uz.trim() && o.uz !== o.ru && !SCHOOL_CHILD_EN[o.uz.trim()]) missing.push(o.uz);
        return;
      }
      Object.values(o).forEach(walk);
    };
    walk(PSYCH_TEMPLATES);
    expect(missing).toEqual([]);
  });
});
