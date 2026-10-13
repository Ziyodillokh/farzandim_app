import {
  isReviewFamilyCode,
  parseReviewFamilyCodes,
} from './review-family-codes';

describe('review family codes (F7)', () => {
  it('merges the legacy single code and the new comma-separated list', () => {
    const codes = parseReviewFamilyCodes('11111', ' 22222 , 33333,');

    expect([...codes].sort()).toEqual(['11111', '22222', '33333']);
  });

  it('accepts a comma-separated list in the legacy variable too', () => {
    expect(parseReviewFamilyCodes('11111,22222').has('22222')).toBe(true);
  });

  it('ignores empty and malformed entries instead of throwing', () => {
    const codes = parseReviewFamilyCodes(undefined, '', '123,1234567, ,abcde');

    expect([...codes]).toEqual(['abcde']);
  });

  it('recognises each store code independently', () => {
    const env = {
      PLAY_REVIEW_FAMILY_CODE: '11111',
      APP_REVIEW_FAMILY_CODES: '22222',
    };

    expect(isReviewFamilyCode('11111', env)).toBe(true);
    expect(isReviewFamilyCode('22222', env)).toBe(true);
    expect(isReviewFamilyCode('33333', env)).toBe(false);
  });

  it('returns false when nothing is configured', () => {
    expect(isReviewFamilyCode('11111', {})).toBe(false);
  });
});
