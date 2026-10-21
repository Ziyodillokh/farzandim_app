import { decideAnswer } from './answer';
import { TEXT_ANSWER_MAX_LENGTH } from './catalog';

const likert = { answerType: 'likert_5', options: [1, 2, 3, 4, 5].map((value) => ({ value })) };
const open = { answerType: 'text', options: [] };

describe('kelajak javob tekshiruvi', () => {
  it('shkala: faqat variantdagi butun qiymat', () => {
    expect(decideAnswer(likert, { value: 4 })).toEqual({ ok: true, kind: 'value', value: 4 });
    expect(decideAnswer(likert, { value: 6 }).ok).toBe(false);
    expect(decideAnswer(likert, { value: 0 }).ok).toBe(false);
    expect(decideAnswer(likert, { value: 2.5 }).ok).toBe(false);
    expect(decideAnswer(likert, {}).ok).toBe(false);
    expect(decideAnswer(likert, { value: 3, text: 'x' }).ok).toBe(false);
    expect(decideAnswer(likert, { text: 'x' }).ok).toBe(false);
  });

  it('ochiq savol: matn (trim), bo\'sh matn — o\'chirish, value — xato', () => {
    expect(decideAnswer(open, { text: '  Salom  ' })).toEqual({ ok: true, kind: 'text', text: 'Salom' });
    expect(decideAnswer(open, { text: '' })).toEqual({ ok: true, kind: 'clear' });
    expect(decideAnswer(open, { text: '   ' })).toEqual({ ok: true, kind: 'clear' });
    expect(decideAnswer(open, { value: 1 }).ok).toBe(false);
    expect(decideAnswer(open, {}).ok).toBe(false);
    expect(decideAnswer(open, { text: 'a'.repeat(TEXT_ANSWER_MAX_LENGTH + 1) }).ok).toBe(false);
    expect(decideAnswer(open, { text: 'a'.repeat(TEXT_ANSWER_MAX_LENGTH) }).ok).toBe(true);
  });
});
