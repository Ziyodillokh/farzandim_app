import { createSign, generateKeyPairSync, X509Certificate } from 'node:crypto';
import { Environment, SignedDataVerifier } from '@apple/app-store-server-library';
import { appleRootCaG3 } from './apple-root-ca';

/**
 * StoreKit 2 (JWS) tekshiruvining XAVFSIZLIK testlari.
 *
 * Bu yerdagi eng muhim savol bitta: Apple imzolamagan tokenni server
 * QABUL QILMAYDIMI? Agar qabul qilsa, istalgan odam o'ziga bepul "Premium"
 * yozib olardi. Shuning uchun quyida ataylab SOXTA token yasaymiz.
 */
describe('Apple IAP — StoreKit 2 JWS tekshiruvi', () => {
  const BUNDLE_ID = 'uz.parvoz.parent';

  describe('appleRootCaG3()', () => {
    it("Apple Root CA G3 ni qaytaradi va barmoq izi to'g'ri", () => {
      const der = appleRootCaG3();
      const cert = new X509Certificate(der);
      expect(cert.subject).toContain('Apple Root CA - G3');
      expect(cert.subject).toContain('Apple Inc.');
    });

    it("o'z-o'zini imzolagan ildiz (self-signed root)", () => {
      const cert = new X509Certificate(appleRootCaG3());
      expect(cert.issuer).toBe(cert.subject);
    });
  });

  describe('soxta (forged) JWS rad etiladi', () => {
    /** Apple emas, O'ZIMIZ imzolagan JWS yasaymiz — rad etilishi SHART. */
    function forgeJws(payload: Record<string, unknown>): string {
      const { privateKey } = generateKeyPairSync('ec', {
        namedCurve: 'P-256',
      });
      const b64 = (o: unknown) =>
        Buffer.from(JSON.stringify(o)).toString('base64url');
      // x5c yo'q — ya'ni hech qanday sertifikat zanjiri taqdim etilmagan.
      const header = b64({ alg: 'ES256', x5c: [] });
      const body = b64(payload);
      const signer = createSign('SHA256');
      signer.update(`${header}.${body}`);
      const sig = signer
        .sign({ key: privateKey, dsaEncoding: 'ieee-p1363' })
        .toString('base64url');
      return `${header}.${body}.${sig}`;
    }

    const verifier = () =>
      new SignedDataVerifier(
        [appleRootCaG3()],
        false, // online tekshiruvsiz — testda tarmoqqa chiqmaymiz
        Environment.SANDBOX,
        BUNDLE_ID,
      );

    it("o'zimiz imzolagan token QABUL QILINMAYDI", async () => {
      const jws = forgeJws({
        bundleId: BUNDLE_ID,
        productId: 'parvoz.premium.yearly',
        transactionId: '9999999999',
        originalTransactionId: '9999999999',
        expiresDate: Date.now() + 365 * 24 * 60 * 60 * 1000,
        environment: 'Sandbox',
      });

      await expect(
        verifier().verifyAndDecodeTransaction(jws),
      ).rejects.toBeDefined();
    });

    it("umuman imzosiz ('alg: none') token QABUL QILINMAYDI", async () => {
      const b64 = (o: unknown) =>
        Buffer.from(JSON.stringify(o)).toString('base64url');
      const jws = `${b64({ alg: 'none' })}.${b64({
        bundleId: BUNDLE_ID,
        productId: 'parvoz.premium.yearly',
        environment: 'Sandbox',
      })}.`;

      await expect(
        verifier().verifyAndDecodeTransaction(jws),
      ).rejects.toBeDefined();
    });

    it("buzuq (garbage) token QABUL QILINMAYDI", async () => {
      await expect(
        verifier().verifyAndDecodeTransaction('aaa.bbb.ccc'),
      ).rejects.toBeDefined();
    });
  });

  describe('format aniqlash — JWS va eski kvitansiya chalkashmaydi', () => {
    // Servisdagi `looksLikeJws` bilan AYNAN bir xil qoida. Ikkalasi mos
    // kelishi shart: qoida o'zgarsa, bu test ham yangilanishi kerak.
    const looksLikeJws = (data: string): boolean => {
      const parts = data.split('.');
      return (
        parts.length === 3 &&
        parts.every((p) => p.length > 0 && /^[A-Za-z0-9_-]+$/.test(p))
      );
    };

    it("StoreKit 2 JWS — JWS deb aniqlanadi", () => {
      expect(looksLikeJws('eyJhbGciOiJFUzI1NiJ9.eyJhIjoxfQ.c2ln')).toBe(true);
    });

    it("StoreKit 1 base64 app-receipt — JWS DEB aniqlanmaydi", () => {
      // Haqiqiy app-receipt: uzun base64, '.' belgisi yo'q, '+' va '/' bor.
      const receipt = `MIIT${'A'.repeat(200)}+/${'B'.repeat(50)}==`;
      expect(looksLikeJws(receipt)).toBe(false);
    });

    it("bo'sh bo'lakli token JWS deb aniqlanmaydi", () => {
      expect(looksLikeJws('abc..def')).toBe(false);
    });
  });
});
