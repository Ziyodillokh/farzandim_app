import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { PaymentsService } from './payments.service';

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

  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
  ) {}

  async verify(
    userId: string,
    dto: {
      productId: string;
      verificationData: string;
      transactionId?: string;
    },
  ): Promise<{ ok: boolean; reason?: string }> {
    const secret = process.env.APPLE_IAP_SHARED_SECRET;
    if (!secret) {
      throw new ServiceUnavailableException('Apple IAP not configured');
    }

    const parsed = parseProductId(dto.productId);
    if (!parsed) throw new BadRequestException('Unknown productId');

    const receipt = await this.verifyReceipt(dto.verificationData, secret);
    if (!receipt || receipt.status !== 0) {
      this.logger.warn(`verifyReceipt status=${receipt?.status ?? 'null'}`);
      throw new BadRequestException('Receipt verification failed');
    }

    const infos = receipt.latest_receipt_info ?? receipt.receipt?.in_app ?? [];
    const forProduct = infos.filter((t) => t.product_id === dto.productId);
    if (forProduct.length === 0) {
      throw new BadRequestException('Product not found in receipt');
    }
    // Eng so'nggi (eng katta expires_date_ms) tranzaksiya.
    forProduct.sort(
      (a, b) => Number(b.expires_date_ms ?? 0) - Number(a.expires_date_ms ?? 0),
    );
    const latest = forProduct[0];
    const expiresMs = Number(latest.expires_date_ms ?? 0);
    const originalTxId = String(
      latest.original_transaction_id ??
        latest.transaction_id ??
        dto.transactionId ??
        '',
    );

    // Muddati o'tgan obuna — entitlement bermaymiz (xato emas, jim rad).
    if (expiresMs > 0 && expiresMs <= Date.now()) {
      return { ok: false, reason: 'expired' };
    }

    // Idempotency: shu tranzaksiya bo'yicha allaqachon obuna berilgan bo'lsa.
    if (originalTxId) {
      const existing = await this.prisma.payment.findFirst({
        where: { method: 'apple', externalId: originalTxId, status: 'success' },
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
        externalId: originalTxId || null,
      },
    });

    await this.payments.markPaymentSuccess(payment.id, {
      externalId: originalTxId || undefined,
      providerData: latest,
      notes: `Apple IAP ${dto.productId}`,
    });

    return { ok: true };
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
