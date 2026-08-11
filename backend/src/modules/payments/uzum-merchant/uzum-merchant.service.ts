import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../common/database/prisma.service';
import { EnvConfig } from '../../../common/config/env.schema';
import { PaymentsService } from '../payments.service';
import {
  ACCOUNT_PARAM_KEYS,
  PLAN_PARAM_KEYS,
  UzumErrorCode,
  UzumStatus,
  somToTiyin,
  tiyinToSom,
} from './uzum-merchant.constants';

/** Uzum yuboradigan so'rov (umumiy shakl). */
interface UzumRequest {
  serviceId?: unknown;
  timestamp?: unknown;
  transId?: unknown;
  amount?: unknown;
  params?: Record<string, unknown>;
}

/** `method: 'uzum'` — Payment jadvalidagi provayder belgisi. */
const METHOD = 'uzum';

/** Uzum `transId` → `Payment.idempotencyKey` (takroriy create'ni bloklaydi). */
const idemKey = (transId: string): string => `uzum:${transId}`;

/**
 * Uzum Bank MERCHANT API — Uzum BIZGA yuboradigan so'rovlar mantiqi.
 *
 * Foydalanuvchi Uzum ilovasida "Parvoz" xizmatini topib, o'z TELEFON
 * RAQAMINI kiritadi va to'laydi. Uzum ketma-ket chaqiradi:
 *   check   — bunday abonent bormi? (to'lovdan oldin)
 *   create  — tranzaksiyani yaratish (PENDING)
 *   confirm — to'lov o'tdi → obunani YOQAMIZ
 *   reverse — bekor qilish → obunani bekor qilamiz
 *   status  — tranzaksiya holati
 *
 * MUHIM: yangi jadval YO'Q — mavjud `Payment` modeli ishlatiladi (Click
 * bilan bir xil), shuning uchun obuna berish/bekor qilish allaqachon
 * sinovdan o'tgan `PaymentsService` orqali ketadi.
 *
 * Summalar: Uzum TIYINDA yuboradi, `Payment.amount` SO'MDA saqlanadi.
 */
@Injectable()
export class UzumMerchantService {
  private readonly logger = new Logger(UzumMerchantService.name);
  private readonly serviceId?: number;

  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
    config: ConfigService<EnvConfig, true>,
  ) {
    this.serviceId =
      config.get('UZUM_MERCHANT_API_SERVICE_ID', { infer: true }) ?? undefined;
  }

  // ─────────────────────────── check ───────────────────────────
  async check(body: UzumRequest) {
    const serviceId = this.num(body.serviceId);
    const ts = Date.now();

    if (!this.validServiceId(serviceId)) {
      return this.failCheck(serviceId, ts, UzumErrorCode.InvalidServiceId);
    }

    const account = this.extractAccount(body.params);
    if (!account) {
      return this.failCheck(
        serviceId,
        ts,
        UzumErrorCode.NotEnoughParamsInRequest,
      );
    }

    const user = await this.findUserByAccount(account);
    if (!user) {
      this.logger.warn(
        `check: abonent topilmadi (${this.accountValue(account)})`,
      );
      return this.failCheck(
        serviceId,
        ts,
        UzumErrorCode.AdditionalPaymentPropertyNotFound,
      );
    }

    return {
      serviceId,
      timestamp: ts,
      status: UzumStatus.Ok,
      data: { account: { value: this.accountValue(account) } },
    };
  }

  // ─────────────────────────── create ──────────────────────────
  async create(body: UzumRequest) {
    const serviceId = this.num(body.serviceId);
    const ts = Date.now();
    const transId = this.str(body.transId);

    if (!this.validServiceId(serviceId)) {
      return this.failCheck(serviceId, ts, UzumErrorCode.InvalidServiceId);
    }
    if (!transId) {
      return this.failCheck(
        serviceId,
        ts,
        UzumErrorCode.NotEnoughParamsInRequest,
      );
    }

    const amountTiyin = this.num(body.amount);
    if (amountTiyin === undefined || amountTiyin <= 0) {
      return this.failCheck(
        serviceId,
        ts,
        UzumErrorCode.NotEnoughParamsInRequest,
      );
    }

    // Idempotentlik: Uzum timeout'da create'ni QAYTA yuborishi mumkin.
    // Bir xil transId hali PENDING bo'lsa — o'sha javobni qaytaramiz
    // (yangi Payment yaratmaymiz). Allaqachon yakunlangan bo'lsa — xato.
    const existing = await this.prisma.payment.findUnique({
      where: { idempotencyKey: idemKey(transId) },
    });
    if (existing) {
      if (existing.status === 'pending') {
        return {
          serviceId,
          timestamp: ts,
          status: UzumStatus.Created,
          transTime: existing.createdAt.valueOf(),
          transId,
          amount: somToTiyin(existing.amount),
        };
      }
      return this.failCheck(
        serviceId,
        ts,
        UzumErrorCode.PaymentAlreadyProcessed,
      );
    }

    const account = this.extractAccount(body.params);
    if (!account) {
      return this.failCheck(
        serviceId,
        ts,
        UzumErrorCode.NotEnoughParamsInRequest,
      );
    }

    const user = await this.findUserByAccount(account);
    if (!user) {
      return this.failCheck(
        serviceId,
        ts,
        UzumErrorCode.AdditionalPaymentPropertyNotFound,
      );
    }

    const amountSom = tiyinToSom(amountTiyin);
    const plan = await this.resolvePlan(body.params, amountSom);
    if (!plan) {
      this.logger.warn(
        `create: tarif aniqlanmadi (amount=${amountSom} so'm, transId=${transId})`,
      );
      return this.failCheck(
        serviceId,
        ts,
        UzumErrorCode.ErrorCheckingPaymentData,
      );
    }

    const payment = await this.prisma.payment.create({
      data: {
        userId: user.id,
        planId: plan.id,
        planName: plan.name,
        amount: amountSom,
        method: METHOD,
        status: 'pending',
        externalId: transId,
        idempotencyKey: idemKey(transId),
        providerData: { uzum: { ...body } } as Prisma.InputJsonValue,
      },
    });

    return {
      serviceId,
      timestamp: ts,
      status: UzumStatus.Created,
      transTime: payment.createdAt.valueOf(),
      transId,
      amount: amountTiyin,
    };
  }

  // ────────────────────────── confirm ──────────────────────────
  async confirm(body: UzumRequest) {
    const serviceId = this.num(body.serviceId);
    const transId = this.str(body.transId);
    const now = Date.now();

    if (!this.validServiceId(serviceId)) {
      return this.failTrans(
        serviceId,
        transId,
        UzumErrorCode.InvalidServiceId,
        { confirmTime: now },
      );
    }
    const payment = transId ? await this.findByTransId(transId) : null;
    if (!payment) {
      return this.failTrans(
        serviceId,
        transId,
        UzumErrorCode.AdditionalPaymentPropertyNotFound,
        { confirmTime: now },
      );
    }

    // Bekor qilingan tranzaksiyani tasdiqlab bo'lmaydi.
    if (payment.status === 'cancelled' || payment.status === 'refunded') {
      return this.failTrans(
        serviceId,
        transId,
        UzumErrorCode.PaymentCancelled,
        { confirmTime: now },
      );
    }
    // Idempotent: allaqachon muvaffaqiyatli bo'lsa yana CONFIRMED qaytaramiz
    // (Uzum retry qilsa obuna IKKI marta uzaytirilmasin).
    if (payment.status === 'success') {
      return {
        serviceId,
        transId,
        status: UzumStatus.Confirmed,
        confirmTime: (payment.paidAt ?? payment.updatedAt).valueOf(),
      };
    }

    // Obunani YOQADI (Click oqimi bilan bir xil, sinovdan o'tgan yo'l).
    const updated = await this.payments.markPaymentSuccess(payment.id, {
      externalId: transId ?? undefined,
      notes: `Uzum Merchant confirm (transId=${transId})`,
    });

    return {
      serviceId,
      transId,
      status: UzumStatus.Confirmed,
      confirmTime: (updated.paidAt ?? new Date()).valueOf(),
    };
  }

  // ────────────────────────── reverse ──────────────────────────
  async reverse(body: UzumRequest) {
    const serviceId = this.num(body.serviceId);
    const transId = this.str(body.transId);
    const now = Date.now();

    if (!this.validServiceId(serviceId)) {
      return this.failTrans(
        serviceId,
        transId,
        UzumErrorCode.InvalidServiceId,
        { reverseTime: now },
      );
    }
    const payment = transId ? await this.findByTransId(transId) : null;
    if (!payment) {
      return this.failTrans(
        serviceId,
        transId,
        UzumErrorCode.AdditionalPaymentPropertyNotFound,
        { reverseTime: now },
      );
    }

    // Idempotent: allaqachon bekor qilingan bo'lsa qayta bekor qilmaymiz.
    if (payment.status !== 'cancelled') {
      await this.payments.markPaymentCancelled(payment.id, {
        notes: `Uzum Merchant reverse (transId=${transId})`,
      });
    }

    return {
      serviceId,
      transId,
      status: UzumStatus.Reversed,
      reverseTime: now,
      amount: somToTiyin(payment.amount),
    };
  }

  // ─────────────────────────── status ──────────────────────────
  async status(body: UzumRequest) {
    const serviceId = this.num(body.serviceId);
    const transId = this.str(body.transId);

    if (!this.validServiceId(serviceId)) {
      return this.failTrans(serviceId, transId, UzumErrorCode.InvalidServiceId);
    }
    const payment = transId ? await this.findByTransId(transId) : null;
    if (!payment) {
      return this.failTrans(
        serviceId,
        transId,
        UzumErrorCode.AdditionalPaymentPropertyNotFound,
      );
    }

    return {
      serviceId,
      transId,
      status: this.mapStatus(payment.status),
    };
  }

  // ─────────────────────────── helpers ─────────────────────────

  /** `Payment.status` → Uzum status kodi. */
  private mapStatus(status: string) {
    switch (status) {
      case 'pending':
        return UzumStatus.Created;
      case 'success':
        return UzumStatus.Confirmed;
      case 'cancelled':
      case 'refunded':
        return UzumStatus.Reversed;
      default:
        return UzumStatus.Failed;
    }
  }

  private findByTransId(transId: string) {
    return this.prisma.payment.findUnique({
      where: { idempotencyKey: idemKey(transId) },
    });
  }

  private validServiceId(serviceId?: number): boolean {
    // Env sozlanmagan bo'lsa serviceId tekshiruvi o'tkazib yuborilmaydi —
    // aksincha, HAMMA so'rov rad etiladi (xavfsiz standart).
    if (this.serviceId === undefined) return false;
    return serviceId === this.serviceId;
  }

  /**
   * `params` ichidan abonent identifikatorini oladi.
   *
   * Asosiy holat — TELEFON raqami (Uzum ilovasida foydalanuvchi shuni
   * kiritadi, `+998XXXXXXXXX` ga normallashtiriladi). Qo'shimcha ravishda
   * EMAIL ham qabul qilinadi: bazada `email` ham unique, ba'zi ota-onalar
   * faqat email bilan ro'yxatdan o'tgan bo'lishi mumkin va sinov uchun ham
   * qulay.
   */
  private extractAccount(
    params: Record<string, unknown> | undefined,
  ): { phone: string } | { email: string } | null {
    if (!params) return null;
    for (const key of ACCOUNT_PARAM_KEYS) {
      const raw = params[key];
      if (typeof raw !== 'string' && typeof raw !== 'number') continue;
      const value = String(raw).trim();
      if (value.length === 0) continue;

      const phone = this.normalizePhone(value);
      if (phone) return { phone };
      if (value.includes('@')) return { email: value.toLowerCase() };
    }
    return null;
  }

  /** Abonentni telefon yoki email bo'yicha topadi. */
  private findUserByAccount(account: { phone: string } | { email: string }) {
    return this.prisma.user.findUnique({ where: account });
  }

  /** Log/`data.account.value` uchun ko'rinadigan qiymat. */
  private accountValue(account: { phone: string } | { email: string }): string {
    return 'phone' in account ? account.phone : account.email;
  }

  /**
   * Har xil ko'rinishdagi raqamni bazadagi `+998XXXXXXXXX` formatiga keltiradi
   * (`901234567`, `998901234567`, `+998 90 123-45-67` — hammasi bir xil).
   */
  private normalizePhone(raw: string): string | null {
    const digits = raw.replace(/\D/g, '');
    if (digits.length === 9) return `+998${digits}`;
    if (digits.length === 12 && digits.startsWith('998')) return `+${digits}`;
    return null;
  }

  /**
   * Tarifni aniqlaydi: avval `params` dagi kod bo'yicha (agar Uzum yuborsa),
   * bo'lmasa SUMMA bo'yicha (oylik = priceUzs, yillik = priceUzs × 10 —
   * Click oqimidagi bilan aynan bir xil mantiq).
   */
  private async resolvePlan(
    params: Record<string, unknown> | undefined,
    amountSom: number,
  ) {
    const plans = await this.prisma.plan.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
    });

    // 1) Aniq kod berilgan bo'lsa — o'sha (summa ham mos kelishi shart).
    for (const key of PLAN_PARAM_KEYS) {
      const raw = params?.[key];
      if (typeof raw !== 'string' || raw.length === 0) continue;
      const plan = plans.find((p) => p.slug === raw || p.id === raw);
      if (!plan) continue;
      const monthly = plan.priceUzs;
      const yearly = plan.priceUzs * 10;
      return amountSom === monthly || amountSom === yearly ? plan : null;
    }

    // 2) Summa bo'yicha: avval oylik, keyin yillik. Ikki xil tarif bir xil
    //    summaga to'g'ri kelsa — noaniq, rad etamiz (xato tarif berilmasin).
    const monthly = plans.filter((p) => p.priceUzs === amountSom);
    if (monthly.length === 1) return monthly[0];
    if (monthly.length > 1) return null;

    const yearly = plans.filter((p) => p.priceUzs * 10 === amountSom);
    if (yearly.length === 1) return yearly[0];
    return null;
  }

  private num(v: unknown): number | undefined {
    if (typeof v === 'number' && Number.isFinite(v)) return v;
    if (typeof v === 'string' && v.trim() !== '' && !isNaN(Number(v))) {
      return Number(v);
    }
    return undefined;
  }

  private str(v: unknown): string | null {
    if (typeof v === 'string' && v.length > 0) return v;
    if (typeof v === 'number') return String(v);
    return null;
  }

  /** check/create uchun xato javobi. */
  private failCheck(
    serviceId: number | undefined,
    timestamp: number,
    errorCode: number,
  ) {
    return {
      serviceId: serviceId ?? null,
      timestamp,
      status: UzumStatus.Failed,
      errorCode,
    };
  }

  /** confirm/reverse/status uchun xato javobi. */
  private failTrans(
    serviceId: number | undefined,
    transId: string | null,
    errorCode: number,
    extra: Record<string, number> = {},
  ) {
    return {
      serviceId: serviceId ?? null,
      transId,
      status: UzumStatus.Failed,
      errorCode,
      ...extra,
    };
  }
}
