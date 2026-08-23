import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  Environment,
  SignedDataVerifier,
  VerificationException,
  VerificationStatus,
} from '@apple/app-store-server-library';
import { PrismaService } from '../../common/database/prisma.service';
import { PaymentsService } from './payments.service';
import { appleRootCaG3 } from './apple-root-ca';

// Apple verifyReceipt endpointlari (legacy, lekin ishlaydi). Kelajakda App
// Store Server API (StoreKit2 JWS) ga o'tish mumkin.
const VERIFY_PROD = 'https://buy.itunes.apple.com/verifyReceipt';
const VERIFY_SANDBOX = 'https://sandbox.itunes.apple.com/verifyReceipt';
// 21007 = sandbox kvitansiyasi prod endpointga yuborilgan -> sandboxga qayta.
const STATUS_SANDBOX_RECEIPT = 21007;

interface AppleTransaction {
  product_id?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  expires_date_ms?: string;
}

interface AppleReceiptResponse {
  status?: number;
  latest_receipt_info?: AppleTransaction[];
  receipt?: { in_app?: AppleTransaction[] };
}

/** `com.farzandim.parent.<tier>.<monthly|yearly>` -> { tier, yearly }. */
function parseProductId(
  productId: string,
): { tier: string; yearly: boolean } | null {
  const m = productId.match(/\.(standard|premium)\.(monthly|yearly)$/);
  if (!m) return null;
  return { tier: m[1], yearly: m[2] === 'yearly' };
}

/**
 * Apple IAP (StoreKit) xaridini tekshirish va obuna berish.
 *
 * Konfiguratsiya: `APPLE_IAP_SHARED_SECRET` (App Store Connect > App Information
 * > App-Specific Shared Secret). O'rnatilmagan bo'lsa endpoint 503 qaytaradi
 * (inert) — mavjud xatti-harakatga ta'sir qilmaydi.
 */
@Injectable()
export class AppleIapService {
  private readonly logger = new Logger(AppleIapService.name);

  /** Lazy qurilgan JWS verifier'lar (production + sandbox). */
  private verifiers?: SignedDataVerifier[];

  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
  ) {}

  async verify(
    userId: string,
    dto: {
      productId?: string;
      verificationData: string;
      transactionId?: string;
    },
  ): Promise<{ ok: boolean; reason?: string }> {
    // productId oldindan berilgan bo'lsa (xarid/restore) shuni tekshiramiz;
    // bo'lmasa (renewal-poll) parseProductId'ga mos KELGAN barcha yozuvlar
    // orasidan izlaymiz.
    if (dto.productId && !parseProductId(dto.productId)) {
      throw new BadRequestException('Unknown productId');
    }

    // ⚠️ IKKI XIL FORMAT — ikkalasi ham qo'llab-quvvatlanadi:
    //
    //   1) JWS (StoreKit 2).  `in_app_purchase_storekit` 0.4.0 dan boshlab
    //      StoreKit 2 STANDART bo'lgan va `serverVerificationData` endi
    //      `header.payload.signature` ko'rinishidagi Apple imzolagan token.
    //      Eski `verifyReceipt` bunday tokenni tushunmaydi (21002 malformed)
    //      — ya'ni bu yo'l qo'shilmaguncha iPhone'da foydalanuvchi PUL
    //      TO'LAB, obuna OLMASDAN qolardi.
    //
    //   2) Base64 app-receipt (StoreKit 1).  `AppleReceiptSyncService`
    //      `refreshPurchaseVerificationData()` orqali AYNAN shuni yuboradi
    //      (obunani davriy sinxronlash uchun), shuning uchun eski yo'l
    //      OLIB TASHLANMAYDI — u hali ham ishlaydi.
    //
    // Formatni tokenning o'zidan aniqlaymiz, klient nima deyishiga
    // ishonmaymiz.
    const candidates = AppleIapService.looksLikeJws(dto.verificationData)
      ? await this.candidatesFromJws(dto.verificationData, dto.productId)
      : await this.candidatesFromReceipt(dto.verificationData, dto.productId);
    if (candidates.length === 0) {
      // Renewal-poll'da mos yozuv topilmasa — bu XATO emas (foydalanuvchida
      // hali Apple obunasi yo'q bo'lishi mumkin), jim rad.
      if (!dto.productId) return { ok: false, reason: 'no_subscription' };
      throw new BadRequestException('Product not found in receipt');
    }
    // Eng so'nggi (eng katta expires_date_ms) tranzaksiya — bir nechta
    // mahsulot bo'lsa ham (masalan standard->premium upgrade) ENG YANGI
    // aktiv obunani tanlaydi.
    candidates.sort(
      (a, b) => Number(b.expires_date_ms ?? 0) - Number(a.expires_date_ms ?? 0),
    );
    const latest = candidates[0];
    const resolvedProductId = latest.product_id ?? dto.productId;
    const parsed = resolvedProductId ? parseProductId(resolvedProductId) : null;
    if (!parsed) throw new BadRequestException('Unknown productId');
    const expiresMs = Number(latest.expires_date_ms ?? 0);

    // MUHIM: `transaction_id` — AYNAN shu tranzaksiya/renewal-siklga xos,
    // HAR renewal'da YANGISI keladi. `original_transaction_id` esa obuna
    // umri davomida O'ZGARMAYDI (birinchi xariddan boshlab bir xil qoladi).
    // Idempotency kalitini `original_transaction_id` bo'yicha qilish
    // RENEWAL'NI BUTUNLAY BUZAR EDI: birinchi xariddan keyin har qanday
    // keyingi tekshiruv (hatto YANGI renewal bo'lsa ham) "allaqachon
    // mavjud" deb to'xtab, `expiresAt` HECH QACHON uzaytirilmasdi. Shu
    // sabab idempotency AYNAN `transactionId` (renewal-specific) bo'yicha.
    const transactionId = String(
      latest.transaction_id ?? dto.transactionId ?? '',
    );
    const originalTransactionId = String(
      latest.original_transaction_id ?? transactionId,
    );

    // Muddati o'tgan obuna — entitlement bermaymiz (xato emas, jim rad).
    // 2 daqiqalik zaxira: server-qurilma soat farqi va sandboxdagi juda
    // qisqa (5-daqiqalik) obunalarda tekshiruv poygasi radga aylanmasin.
    // Production oyligi 30 kun — 2 daqiqa u yerda hech narsani o'zgartirmaydi.
    const EXPIRY_GRACE_MS = 2 * 60 * 1000;
    if (expiresMs > 0 && expiresMs + EXPIRY_GRACE_MS <= Date.now()) {
      return { ok: false, reason: 'expired' };
    }

    // Idempotency: AYNAN shu renewal-tranzaksiya uchun allaqachon entitlement
    // berilganmi (bir xil oyda ilova bir necha marta ochilganda takroriy
    // Payment yozuv/uzaytirish bo'lmasin).
    if (transactionId) {
      const existing = await this.prisma.payment.findFirst({
        where: { method: 'apple', externalId: transactionId, status: 'success' },
      });
      if (existing) return { ok: true };
    }

    const plan = await this.prisma.plan.findFirst({
      where: { entitlementTier: parsed.tier, isActive: true },
      orderBy: { sortOrder: 'asc' },
    });
    if (!plan) throw new BadRequestException(`No plan for tier ${parsed.tier}`);

    // Yillik = priceUzs*10 (activateSubscriptionTx summadan 365 kun aniqlaydi,
    // Click oqimidagi bilan bir xil mantiq).
    const amount = parsed.yearly ? plan.priceUzs * 10 : plan.priceUzs;
    const payment = await this.prisma.payment.create({
      data: {
        userId,
        planId: plan.id,
        planName: plan.name,
        amount,
        method: 'apple',
        status: 'pending',
        externalId: transactionId || null,
      },
    });

    await this.payments.markPaymentSuccess(payment.id, {
      externalId: transactionId || undefined,
      providerData: latest,
      notes: `Apple IAP ${resolvedProductId} (original_transaction_id=${originalTransactionId})`,
    });

    return { ok: true };
  }

  /**
   * Token StoreKit 2 JWS'imi? `header.payload.signature` — uchta base64url
   * bo'lak. Base64 app-receipt'da esa `.` belgisi umuman uchramaydi, ya'ni
   * ikki format bir-biri bilan chalkashmaydi.
   */
  private static looksLikeJws(data: string): boolean {
    const parts = data.split('.');
    return (
      parts.length === 3 &&
      parts.every((p) => p.length > 0 && /^[A-Za-z0-9_-]+$/.test(p))
    );
  }

  /**
   * SignedDataVerifier'lar (production + sandbox), bir marta quriladi.
   *
   * Ikkitasi kerak, chunki `verifyAndDecodeTransaction` tranzaksiyaning
   * `environment` maydonini verifier'nikiga qat'iy solishtiradi va mos
   * kelmasa xato beradi — eski `verifyReceipt`dagi PROD→SANDBOX fallback
   * mantiqining aynan o'zi.
   */
  private buildVerifiers(): SignedDataVerifier[] {
    if (this.verifiers) return this.verifiers;

    const bundleId = process.env.APPLE_BUNDLE_ID || 'uz.parvoz.parent';
    // Sertifikat bekor qilinganini va muddatini ONLINE tekshirish. Xavfsizroq
    // (Apple tavsiyasi), lekin Apple OCSP'siga chiqishni talab qiladi. Agar
    // server Apple'ga chiqa olmasa — `APPLE_IAP_ONLINE_CHECKS=false`.
    const online = process.env.APPLE_IAP_ONLINE_CHECKS !== 'false';
    const roots = [appleRootCaG3()];
    const list: SignedDataVerifier[] = [];

    // PRODUCTION birinchi — real foydalanuvchilarning aksariyati shu yerda.
    const rawId = process.env.APPLE_APP_APPLE_ID;
    const appAppleId = rawId ? Number(rawId) : NaN;
    if (Number.isFinite(appAppleId) && appAppleId > 0) {
      list.push(
        new SignedDataVerifier(
          roots,
          online,
          Environment.PRODUCTION,
          bundleId,
          appAppleId,
        ),
      );
    } else {
      // Kutubxona PRODUCTION verifier'ini appAppleId'siz qurishga YO'L
      // QO'YMAYDI. Bu jimgina o'tib ketmasligi kerak: aks holda TestFlight
      // va App Store xaridlari tekshirilmay qoladi.
      this.logger.error(
        'APPLE_APP_APPLE_ID o\'rnatilmagan — PRODUCTION/TestFlight iOS ' +
          'xaridlari TEKSHIRILMAYDI. Qiymatni App Store Connect > Ilova > ' +
          'App Information > "Apple ID" dan oling (faqat raqamlar).',
      );
    }

    // SANDBOX — appAppleId talab qilmaydi (Xcode/sandbox sinovlari uchun).
    list.push(
      new SignedDataVerifier(roots, online, Environment.SANDBOX, bundleId),
    );

    this.verifiers = list;
    return list;
  }

  /**
   * StoreKit 2 JWS tranzaksiyasini Apple imzosi bo'yicha tekshiradi va eski
   * oqim kutadigan shaklga o'giradi.
   *
   * Imzo Apple Root CA G3 gacha bo'lgan sertifikat zanjiri bilan
   * tasdiqlanadi — ya'ni tokenni Apple'dan boshqa hech kim yasay olmaydi.
   */
  private async candidatesFromJws(
    jws: string,
    expectedProductId?: string,
  ): Promise<AppleTransaction[]> {
    // Bitta O'TKINCHI xato (masalan OCSP/tarmoq hikchiligi — verifier
    // enableOnlineChecks bilan Apple'ning bekor-qilish serverlariga
    // murojaat qiladi) foydalanuvchining muvaffaqiyatli xaridini "yiqilgan"
    // qilib ko'rsatmasligi uchun butun tekshiruv bir marta qayta uriniladi.
    // Apple App Review 2.1(b) radi (2026-08-23) tahlilida shu bo'g'in eng
    // zaif nuqta deb topilgan.
    try {
      return await this.candidatesFromJwsOnce(jws, expectedProductId);
    } catch (e) {
      // Qat'iy radlar (mahsulot mos emas, buzuq token va h.k.) qayta
      // urinilmaydi — faqat O'TKINCHI (503) holat retry qilinadi.
      if (!(e instanceof ServiceUnavailableException)) throw e;
      this.logger.warn('JWS tekshiruvi 1-urinishda yiqildi — qayta urinish');
      await new Promise((r) => setTimeout(r, 400));
      return this.candidatesFromJwsOnce(jws, expectedProductId);
    }
  }

  private async candidatesFromJwsOnce(
    jws: string,
    expectedProductId?: string,
  ): Promise<AppleTransaction[]> {
    const verifiers = this.buildVerifiers();
    const errors: string[] = [];
    let hadRetryable = false;

    for (const verifier of verifiers) {
      try {
        const tx = await verifier.verifyAndDecodeTransaction(jws);
        const productId = tx.productId;
        if (!productId || !parseProductId(productId)) {
          throw new BadRequestException('Unknown productId');
        }
        // Klient aytgan mahsulot Apple imzolagani bilan mos kelishi SHART —
        // aks holda arzon tarif sotib olib, qimmatini so'rash mumkin bo'lardi.
        if (expectedProductId && productId !== expectedProductId) {
          throw new BadRequestException('Product mismatch');
        }
        return [
          {
            product_id: productId,
            transaction_id: tx.transactionId,
            original_transaction_id: tx.originalTransactionId,
            expires_date_ms:
              tx.expiresDate != null ? String(tx.expiresDate) : undefined,
          },
        ];
      } catch (e) {
        if (e instanceof BadRequestException) throw e;
        if (e instanceof VerificationException) {
          // DIQQAT: VerificationException.message doim BO'SH — sababni
          // faqat `status` tashiydi, shuning uchun aynan uni loglaymiz.
          errors.push(`VerificationException(${VerificationStatus[e.status]})`);
          if (e.status === VerificationStatus.RETRYABLE_VERIFICATION_FAILURE) {
            hadRetryable = true;
          }
        } else {
          // Kutubxonadan tashqari xato (masalan OCSP'ga tarmoq uzilishi
          // boshqa ko'rinishda) — buni ham o'tkinchi deb hisoblaymiz.
          errors.push((e as Error)?.message ?? String(e));
          hadRetryable = true;
        }
      }
    }

    this.logger.warn(`JWS tekshiruvi o'tmadi: ${errors.join(' | ')}`);
    if (hadRetryable) {
      // ⚠️ 400 EMAS, 503: kutubxona RETRYABLE_VERIFICATION_FAILURE ni
      // odatda OCSP (online bekor-qilish tekshiruvi) yoki tarmoq
      // hikchiligida otadi. 400 qaytarilsa klient buni QAT'IY rad deb
      // qabul qiladi, tranzaksiyani yopadi va foydalanuvchining
      // MUVAFFAQIYATLI to'lovi "yiqilgan" bo'lib ko'rinadi — Apple App
      // Review 2.1(b) radi (2026-08-23) aynan shu stsenariyga mos.
      // 503 esa klientdagi retry + "to'lov qabul qilindi" yo'liga tushadi.
      throw new ServiceUnavailableException(
        'Receipt verification temporarily unavailable',
      );
    }
    throw new BadRequestException('Receipt verification failed');
  }

  /** Eski (StoreKit 1) base64 app-receipt yo'li — o'zgarishsiz. */
  private async candidatesFromReceipt(
    receiptData: string,
    expectedProductId?: string,
  ): Promise<AppleTransaction[]> {
    const secret = process.env.APPLE_IAP_SHARED_SECRET;
    if (!secret) {
      throw new ServiceUnavailableException('Apple IAP not configured');
    }
    const receipt = await this.verifyReceipt(receiptData, secret);
    if (!receipt || receipt.status !== 0) {
      this.logger.warn(`verifyReceipt status=${receipt?.status ?? 'null'}`);
      throw new BadRequestException('Receipt verification failed');
    }
    const infos = receipt.latest_receipt_info ?? receipt.receipt?.in_app ?? [];
    return expectedProductId
      ? infos.filter((t) => t.product_id === expectedProductId)
      : // Renewal-poll: aniq productId yo'q — kvitansiyadagi BARCHA bizning
        // (standard/premium) mahsulotlarimizga mos yozuvlarni ko'rib
        // chiqamiz (tarif upgrade/downgrade holatini ham to'g'ri qamraydi).
        infos.filter((t) => t.product_id && parseProductId(t.product_id));
  }

  private async verifyReceipt(
    receiptData: string,
    secret: string,
  ): Promise<AppleReceiptResponse | null> {
    const body = JSON.stringify({
      'receipt-data': receiptData,
      password: secret,
      'exclude-old-transactions': false,
    });
    // Avval PROD; sandbox kvitansiyasi bo'lsa (21007) SANDBOX'ga qayta.
    let res = await this.postVerify(VERIFY_PROD, body);
    if (res?.status === STATUS_SANDBOX_RECEIPT) {
      res = await this.postVerify(VERIFY_SANDBOX, body);
    }
    return res;
  }

  private async postVerify(
    url: string,
    body: string,
  ): Promise<AppleReceiptResponse | null> {
    try {
      const resp = await fetch(url, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body,
      });
      return (await resp.json()) as AppleReceiptResponse;
    } catch (e) {
      this.logger.error('verifyReceipt request failed', e as Error);
      return null;
    }
  }
}
