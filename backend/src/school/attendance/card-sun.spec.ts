import { createCipheriv, randomBytes } from 'node:crypto';
import { aesCmac, deriveMetaKey, deriveTagKey, normalizeUid, parseSunParams, sunMac, verifySun } from './card-sun';

const hex = (s: string) => Buffer.from(s, 'hex');
const ZERO = Buffer.alloc(16);

/** Kartaning o'zi qiladigan ish (test uchun): PICCData shifrlash + SDMMAC. */
function emulateTap(metaKey: Buffer, fileKey: Buffer, uid: Buffer, counter: number) {
  const plain = Buffer.alloc(16);
  plain[0] = 0xc7; // UID va hisoblagich aks ettiriladi, UID uzunligi 7
  uid.copy(plain, 1);
  plain.writeUIntLE(counter, 8, 3);
  randomBytes(5).copy(plain, 11);
  const cipher = createCipheriv('aes-128-cbc', metaKey, ZERO).setAutoPadding(false);
  const piccData = Buffer.concat([cipher.update(plain), cipher.final()]);
  const cmac = sunMac(fileKey, Buffer.concat([uid, plain.subarray(8, 11)]));
  return { piccData, cmac };
}

describe('aesCmac (RFC 4493 namunalari)', () => {
  const key = hex('2b7e151628aed2a6abf7158809cf4f3c');

  it.each([
    ['', 'bb1d6929e95937287fa37d129b756746'],
    ['6bc1bee22e409f96e93d7e117393172a', '070a16b46b4d4144f79bdd9dd04a287c'],
    ['6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411', 'dfa66747de9ae63030ca32611497c827'],
    [
      '6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710',
      '51f0bebf7e3b9d92fc49741779363cfe',
    ],
  ])('M=%s', (message, expected) => {
    expect(aesCmac(key, hex(message)).toString('hex')).toBe(expected);
  });
});

describe('verifySun (NTAG 424 DNA, AN12196)', () => {
  it('NXP namunasi: nol kalitlar → UID 04DE5F1EACC040, hisoblagich 61', () => {
    const result = verifySun({ piccData: hex('EF963FF7828658A599F3041510671E88'), cmac: hex('94EED9EE65337086') }, ZERO, () => ZERO);

    expect(result).toEqual({ uid: '04DE5F1EACC040', counter: 61 });
  });

  it("imzo o'zgartirilsa yoki kalit boshqa bo'lsa — rad etiladi", () => {
    const picc = hex('EF963FF7828658A599F3041510671E88');

    expect(verifySun({ piccData: picc, cmac: hex('94EED9EE65337087') }, ZERO, () => ZERO)).toBeNull();
    expect(verifySun({ piccData: picc, cmac: hex('94EED9EE65337086') }, ZERO, () => randomBytes(16))).toBeNull();
    expect(verifySun({ piccData: picc, cmac: hex('94EED9EE65337086') }, randomBytes(16), () => ZERO)).toBeNull();
  });

  it('maktab bosh kalitidan hosila kalitlar bilan: karta tegishi tekshiriladi', () => {
    const master = randomBytes(16);
    const uid = hex('04A1B2C3D4E5F6');
    const tap = emulateTap(deriveMetaKey(master), deriveTagKey(master, uid, 2), uid, 4242);

    const result = verifySun(tap, deriveMetaKey(master), (u) => deriveTagKey(master, u, 2));

    expect(result).toEqual({ uid: '04A1B2C3D4E5F6', counter: 4242 });
    expect(verifySun(tap, deriveMetaKey(randomBytes(16)), (u) => deriveTagKey(master, u, 2))).toBeNull();
  });
});

describe('kalit hosilasi (NXP sdm-backend bilan bir xil)', () => {
  it('nol bosh kalit — zavod kalitlari (nol)', () => {
    expect(deriveMetaKey(ZERO).equals(ZERO)).toBe(true);
    expect(deriveTagKey(ZERO, hex('010203040506AB'), 2).equals(ZERO)).toBe(true);
  });

  it('namunaviy qiymatlar', () => {
    const master = hex('C9EB67DF090AFF47C3B19A2516680B9D');

    expect(deriveMetaKey(master).toString('hex')).toBe('a13086f194d7bdfd108dd11716ea2bdf');
    expect(deriveTagKey(master, hex('010203040506AB'), 1).toString('hex')).toBe('f18cdd9389d47ae7ab381e80e5ab6fe3');
    expect(deriveTagKey(master, hex('03030303030303'), 2).toString('hex')).toBe('85f7cc459a5b4b2f5d1a5019ded61c88');
    expect(deriveTagKey(hex('B95F4C27E3D0BC333792EA968545217F'), hex('05050505050505'), 2).toString('hex')).toBe('89ae686de793fdf48057ee6e78505cfc');
  });
});

describe('parseSunParams va normalizeUid', () => {
  it('kartadagi manzildan p/c, picc_data/cmac yoki e/c parametrlari', () => {
    const expected = { piccData: hex('EF963FF7828658A599F3041510671E88'), cmac: hex('94EED9EE65337086') };

    expect(parseSunParams('https://farzandimedu.uz/k/?p=EF963FF7828658A599F3041510671E88&c=94EED9EE65337086')).toEqual(expected);
    expect(parseSunParams('https://x.uz/tag?picc_data=ef963ff7828658a599f3041510671e88&cmac=94eed9ee65337086')).toEqual(expected);
    expect(parseSunParams('https://ntag.nxp.com/424?e=EF963FF7828658A599F3041510671E88&c=94EED9EE65337086')).toEqual(expected);
  });

  it('kodsiz yoki buzilgan manzil — null', () => {
    expect(parseSunParams('https://farzandimedu.uz/k/')).toBeNull();
    expect(parseSunParams('https://farzandimedu.uz/k/?p=ZZ&c=94EED9EE65337086')).toBeNull();
    expect(parseSunParams('mailto:x@y.uz')).toBeNull();
    expect(parseSunParams('buzilgan')).toBeNull();
  });

  it('UID: Web NFC "04:de:5f:1e:ac:c0:40" va boshqa ko\'rinishlar', () => {
    expect(normalizeUid('04:de:5f:1e:ac:c0:40')).toBe('04DE5F1EACC040');
    expect(normalizeUid('04-DE-5F-1E')).toBe('04DE5F1E');
    expect(normalizeUid(' 04de5f1eacc040 ')).toBe('04DE5F1EACC040');
    expect(normalizeUid('04:de')).toBeNull();
    expect(normalizeUid('salom')).toBeNull();
  });
});
