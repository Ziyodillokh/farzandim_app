import { nameKey, namesMatch } from './child-auto-match';

describe('farzandni ism bo\'yicha moslash', () => {
  it('lotin/kirill, tutuq belgisi, katta-kichik harf va «-jon/-xon» farqsiz', () => {
    expect(namesMatch('Азиза', 'Aziza')).toBe(true);
    expect(namesMatch('Boburjon Karimov', 'Bobur')).toBe(true);
    expect(namesMatch("G'ayrat", 'Gʻayrat')).toBe(true);
    expect(namesMatch('Ўктам', "O'ktam")).toBe(true);
    expect(namesMatch('mohinurxon', 'Mohinur')).toBe(true);
  });

  it('faqat aniq moslik: boshi o\'xshash boshqa ism — yo\'q', () => {
    expect(namesMatch('Ali', 'Alisher')).toBe(false);
    expect(namesMatch('Alisher', 'Ali')).toBe(false);
    expect(namesMatch('Aziz', 'Aziza')).toBe(false);
    expect(namesMatch('Bo', 'Bo')).toBe(false);
  });

  it('qisqa ismda qo\'shimcha kesilmaydi', () => {
    expect(nameKey('Jon')).toBe('jon');
    expect(nameKey('Alijon')).toBe('ali');
  });
});
