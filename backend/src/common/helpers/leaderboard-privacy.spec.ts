import { maskChildName, visibleChildId } from './leaderboard-privacy';

describe('maskChildName (F16)', () => {
  it('keeps the first name and the last-name initial', () => {
    expect(maskChildName('Muhammad Abror Karimov')).toBe('Muhammad K.');
    expect(maskChildName('  Ali   valiyev ')).toBe('Ali V.');
  });

  it("keeps Uzbek apostrophes in names", () => {
    expect(maskChildName("G'ayrat O'ktamov")).toBe("G'ayrat O.");
  });

  it('removes digits and contact handles typed as a name', () => {
    expect(maskChildName('+998901234567')).toBe('—');
    expect(maskChildName('@ali_2010')).toBe('ali');
    expect(maskChildName('Sardor 90-123-45-67')).toBe('Sardor');
  });

  it('handles empty values', () => {
    expect(maskChildName(null)).toBe('—');
    expect(maskChildName('')).toBe('—');
  });

  it('caps very long first names', () => {
    expect(maskChildName('a'.repeat(40))).toHaveLength(20);
  });
});

describe('visibleChildId (F16/F17)', () => {
  it('returns the id only for the viewer family', () => {
    const own = new Set(['mine']);

    expect(visibleChildId('mine', own)).toBe('mine');
    expect(visibleChildId('stranger', own)).toBe('');
  });
});
