import { TEMP_PASSWORD_ALPHABET, TEMP_PASSWORD_LENGTH } from './child-auth.constants';
import {
  checkNewPassword,
  generateTemporaryPassword,
  isValidLogin,
  normalizeLogin,
  splitChildName,
  suggestLoginCandidates,
  toAsciiSlug,
} from './child-credentials.helpers';

describe('login format', () => {
  it('normalizes by trimming and lower-casing; non-strings become empty', () => {
    expect(normalizeLogin('  Aziza.K24 ')).toBe('aziza.k24');
    expect(normalizeLogin(undefined)).toBe('');
    expect(normalizeLogin(42)).toBe('');
  });

  it.each(['aziza.k24', 'a.k1', 'parvoz1234', 'ali_va.2026', 'a'.padEnd(24, 'b')])('accepts %s', (login) => {
    expect(isValidLogin(login)).toBe(true);
  });

  it.each([
    ['abc', 'shorter than 4'],
    ['1abcd', 'starts with a digit'],
    ['.abcd', 'starts with a dot'],
    ['Aziza.K24', 'upper case'],
    ['az iza', 'space'],
    ['aziza-k24', 'dash'],
    ['aziza@k24', 'at sign'],
    ['a'.padEnd(25, 'b'), 'longer than 24'],
    ['', 'empty'],
    ['азиза.к24', 'cyrillic'],
  ])('rejects %s (%s)', (login) => {
    expect(isValidLogin(login)).toBe(false);
  });
});

describe('toAsciiSlug', () => {
  it('transliterates Uzbek Latin apostrophes and diacritics', () => {
    expect(toAsciiSlug('Oʻktam')).toBe('oktam');
    expect(toAsciiSlug("G'ayrat")).toBe('gayrat');
    expect(toAsciiSlug('Zoë')).toBe('zoe');
  });

  it('transliterates Cyrillic (Russian and Uzbek letters)', () => {
    expect(toAsciiSlug('Азиза')).toBe('aziza');
    expect(toAsciiSlug('Ҳамида')).toBe('hamida');
    expect(toAsciiSlug('Ўткир')).toBe('otkir');
    expect(toAsciiSlug('Шахзод')).toBe('shaxzod');
    expect(toAsciiSlug('Юсуф')).toBe('yusuf');
  });

  it('keeps only a-z0-9 and truncates', () => {
    expect(toAsciiSlug('A-li_va!!')).toBe('aliva');
    expect(toAsciiSlug('abcdefghijklmnop', 12)).toBe('abcdefghijkl');
    expect(toAsciiSlug('你好')).toBe('');
  });
});

describe('splitChildName', () => {
  it('uses the first word as first name and the last word as last name', () => {
    expect(splitChildName('Aziza Karimova')).toEqual({ firstName: 'Aziza', lastName: 'Karimova' });
    expect(splitChildName('  Aziza  Bobur qizi Karimova ')).toEqual({ firstName: 'Aziza', lastName: 'Karimova' });
  });

  it('has no last name for a single word or an empty name', () => {
    expect(splitChildName('Aziza')).toEqual({ firstName: 'Aziza', lastName: '' });
    expect(splitChildName('   ')).toEqual({ firstName: '', lastName: '' });
  });
});

describe('suggestLoginCandidates', () => {
  const fixed = (n: number) => () => n;

  it('builds first name + "." + last initial + two digits', () => {
    const candidates = suggestLoginCandidates({ firstName: 'Aziza', lastName: 'Karimova' }, fixed(24));
    expect(candidates[0]).toBe('aziza.k24');
  });

  it('pads digits and works for Cyrillic names', () => {
    const candidates = suggestLoginCandidates({ firstName: 'Азиза', lastName: 'Каримова' }, fixed(7));
    expect(candidates[0]).toBe('aziza.k07');
  });

  it('omits the last initial when there is no last name', () => {
    expect(suggestLoginCandidates({ firstName: 'Aziza' }, fixed(5))[0]).toBe('aziza.05');
  });

  it('always ends with the parvoz + 4 digits fallback and every candidate is valid and unique', () => {
    let seed = 0;
    const candidates = suggestLoginCandidates({ firstName: 'Aziza', lastName: 'K' }, () => seed++ % 100, 8);
    expect(new Set(candidates).size).toBe(candidates.length);
    expect(candidates.every(isValidLogin)).toBe(true);
    expect(candidates.some((c) => /^parvoz\d{4}$/.test(c))).toBe(true);
  });

  it('falls back to parvoz#### when the first name cannot be transliterated or starts with a digit', () => {
    for (const firstName of ['你好', '7-sinf', '']) {
      const candidates = suggestLoginCandidates({ firstName, lastName: 'Karimova' }, fixed(11));
      expect(candidates.length).toBeGreaterThan(0);
      expect(candidates.every((c) => /^parvoz\d{4}$/.test(c))).toBe(true);
    }
  });

  it('truncates a long first name so the login stays within 24 characters', () => {
    const [first] = suggestLoginCandidates({ firstName: 'Abdurahmonovich-Zaynulobiddin', lastName: 'Q' }, fixed(99));
    expect(first).toBe('abdurahmonov.q99');
    expect(isValidLogin(first!)).toBe(true);
  });
});

describe('generateTemporaryPassword', () => {
  it('is 8 characters from the unambiguous alphabet', () => {
    for (let i = 0; i < 300; i++) {
      const password = generateTemporaryPassword();
      expect(password).toHaveLength(TEMP_PASSWORD_LENGTH);
      expect([...password].every((c) => TEMP_PASSWORD_ALPHABET.includes(c))).toBe(true);
    }
  });

  it('never contains look-alike characters (i, l, o, 0, 1)', () => {
    expect(TEMP_PASSWORD_ALPHABET).not.toMatch(/[ilo01]/);
    expect(TEMP_PASSWORD_ALPHABET).toHaveLength(31);
  });

  it('draws from the whole alphabet using the injected random source', () => {
    let i = 0;
    const password = generateTemporaryPassword(() => i++ % TEMP_PASSWORD_ALPHABET.length);
    expect(password).toBe(TEMP_PASSWORD_ALPHABET.slice(0, 8));
  });

  it('does not repeat across calls (crypto random)', () => {
    const seen = new Set(Array.from({ length: 200 }, () => generateTemporaryPassword()));
    expect(seen.size).toBeGreaterThan(195);
  });
});

describe('checkNewPassword', () => {
  const login = 'aziza.k24';

  it('accepts a normal password', () => {
    expect(checkNewPassword('Kitob2026', login)).toBeNull();
    expect(checkNewPassword('mening-parolim7', login)).toBeNull();
    expect(checkNewPassword('Parol123Parol', login)).toBeNull();
  });

  it('requires 8 to 64 characters', () => {
    expect(checkNewPassword('Ab1', login)).toBe('TOO_SHORT');
    expect(checkNewPassword('Abcde12', login)).toBe('TOO_SHORT');
    expect(checkNewPassword('Abcdef12', login)).toBeNull();
    expect(checkNewPassword(`${'a'.repeat(63)}1`, login)).toBeNull();
    expect(checkNewPassword(`${'a'.repeat(64)}1`, login)).toBe('TOO_LONG');
  });

  it('limits the byte length to what bcrypt really uses (72 bytes)', () => {
    // 40 ta kirill harf = 80 bayt (64 belgidan kam, lekin bcrypt kesib tashlardi)
    expect(checkNewPassword(`${'ш'.repeat(40)}1`, login)).toBe('TOO_LONG');
    expect(checkNewPassword(`${'ш'.repeat(30)}1`, login)).toBeNull();
  });

  it('needs at least one letter and one digit', () => {
    expect(checkNewPassword('12345678', login)).toBe('NEEDS_LETTER');
    expect(checkNewPassword('abcdefgh', login)).toBe('NEEDS_DIGIT');
    expect(checkNewPassword('Парольчик1', login)).toBeNull();
  });

  it('rejects the login itself, case-insensitively', () => {
    expect(checkNewPassword('aziza.k24', 'aziza.k24')).toBe('SAME_AS_LOGIN');
    expect(checkNewPassword('AZIZA.K24', 'aziza.k24')).toBe('SAME_AS_LOGIN');
  });

  it('rejects the common-password blocklist, case-insensitively', () => {
    expect(checkNewPassword('Password1', login)).toBe('TOO_COMMON');
    expect(checkNewPassword('QWERTY123', login)).toBe('TOO_COMMON');
    expect(checkNewPassword('Parvoz123', login)).toBe('TOO_COMMON');
  });
});
