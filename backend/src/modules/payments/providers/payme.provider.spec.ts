/**
 * PaymeProvider — Merchant API (JSON-RPC) oqimi testi.
 *
 * Payme sandbox (test.paycom.uz) aynan shu ketma-ketlikni tekshiradi:
 * auth → CheckPerformTransaction → CreateTransaction (+takror, +boshqa id)
 * → PerformTransaction (+takror) → CheckTransaction → CancelTransaction →
 * GetStatement. DB o'rniga xotiradagi soxta Prisma ishlatiladi.
 */
import { PaymeProvider } from './payme.provider';

const MERCHANT_ID = '6a7dc4613febcfd2f87a9eb9';
const KEY = 'test-key';
const AUTH = 'Basic ' + Buffer.from(`Paycom:${KEY}`).toString('base64');

type Row = {
  id: string;
  method: string;
  amount: number;
  status: string;
  planName: string | null;
  externalId: string | null;
  providerData: unknown;
  createdAt: Date;
};

function makeProvider(env: Record<string, unknown> = {}) {
  const rows = new Map<string, Row>();
  const prisma = {
    payment: {
      findUnique: jest.fn(
        async ({ where }: { where: { id: string } }) =>
          rows.get(where.id) ?? null,
      ),
      findFirst: jest.fn(
        async ({ where }: { where: { externalId: string; method: string } }) =>
          [...rows.values()].find(
            (r) =>
              r.externalId === where.externalId && r.method === where.method,
          ) ?? null,
      ),
      findMany: jest.fn(async () => [...rows.values()]),
      update: jest.fn(
        async ({
          where,
          data,
        }: {
          where: { id: string };
          data: Partial<Row>;
        }) => {
          const row = rows.get(where.id)!;
          Object.assign(row, data);
          return row;
        },
      ),
    },
  };
  const paymentsService = {
    markPaymentSuccess: jest.fn(
      async (
        id: string,
        opts: { externalId?: string; providerData?: unknown },
      ) => {
        const row = rows.get(id)!;
        row.status = 'success';
        if (opts.externalId) row.externalId = opts.externalId;
        if (opts.providerData) row.providerData = opts.providerData;
        return row;
      },
    ),
    markPaymentCancelled: jest.fn(
      async (id: string, opts: { providerData?: unknown }) => {
        const row = rows.get(id)!;
        row.status = 'cancelled';
        if (opts.providerData) row.providerData = opts.providerData;
        return row;
      },
    ),
  };
  const cfg = {
    PAYME_MERCHANT_ID: MERCHANT_ID,
    PAYME_MERCHANT_KEY: KEY,
    ...env,
  } as Record<string, unknown>;
  const config = { get: (k: string) => cfg[k] };
  const provider = new PaymeProvider(
    config as never,
    prisma as never,
    paymentsService as never,
  );
  return { provider, rows, prisma, paymentsService };
}

function seedPayment(
  rows: Map<string, Row>,
  overrides: Partial<Row> = {},
): Row {
  const row: Row = {
    id: 'pay_1',
    method: 'payme',
    amount: 29000,
    status: 'pending',
    planName: 'Standart',
    externalId: null,
    providerData: null,
    createdAt: new Date(),
    ...overrides,
  };
  rows.set(row.id, row);
  return row;
}

async function rpc(
  provider: PaymeProvider,
  method: string,
  params: Record<string, unknown>,
  auth: string | null = AUTH,
) {
  const res = await provider.handleWebhook({
    body: { jsonrpc: '2.0', id: 7, method, params },
    rawBody: '',
    headers: auth ? { authorization: auth } : {},
    query: {},
  });
  return res.body as {
    id: unknown;
    result?: Record<string, unknown>;
    error?: { code: number; data?: string };
  };
}

const AMOUNT_TIYIN = 29000 * 100;

describe('PaymeProvider', () => {
  it('checkout URL — base64(m;ac.<field>;a) va sozlanadigan account maydoni', async () => {
    const { provider } = makeProvider({
      PAYME_CHECKOUT_URL: 'https://checkout.test.paycom.uz',
      PAYME_ACCOUNT_FIELD: 'order_id',
    });
    const out = await provider.createCheckout({
      paymentId: 'pay_1',
      amount: 29000,
      planName: 'Standart',
    });
    expect(out.provider).toBe('payme');
    const [base, encoded] = out.checkoutUrl.split(/\/(?=[^/]+$)/);
    expect(base).toBe('https://checkout.test.paycom.uz');
    expect(Buffer.from(encoded, 'base64').toString('utf8')).toBe(
      `m=${MERCHANT_ID};ac.order_id=pay_1;a=${AMOUNT_TIYIN}`,
    );
  });

  it("auth yo'q/xato → -32504 (HTTP 200 JSON-RPC)", async () => {
    const { provider } = makeProvider();
    const noAuth = await rpc(provider, 'CheckPerformTransaction', {}, null);
    expect(noAuth.error?.code).toBe(-32504);
    const wrong = await rpc(
      provider,
      'CheckPerformTransaction',
      {},
      'Basic ' + Buffer.from('Paycom:wrong').toString('base64'),
    );
    expect(wrong.error?.code).toBe(-32504);
    expect(wrong.id).toBe(7);
  });

  it("noma'lum metod → -32601, method yo'q → -32600", async () => {
    const { provider } = makeProvider();
    const r = await rpc(provider, 'Nope', {});
    expect(r.error?.code).toBe(-32601);
    const res = await provider.handleWebhook({
      body: { jsonrpc: '2.0', id: 9, params: {} },
      rawBody: '',
      headers: { authorization: AUTH },
      query: {},
    });
    expect((res.body as { error?: { code: number } }).error?.code).toBe(-32600);
  });

  it('CheckPerformTransaction — account/amount/holat tekshiruvlari', async () => {
    const { provider, rows } = makeProvider();
    seedPayment(rows);

    const notFound = await rpc(provider, 'CheckPerformTransaction', {
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'nope' },
    });
    expect(notFound.error?.code).toBe(-31050);
    expect(notFound.error?.data).toBe('payment_id');

    const badAmount = await rpc(provider, 'CheckPerformTransaction', {
      amount: 100,
      account: { payment_id: 'pay_1' },
    });
    expect(badAmount.error?.code).toBe(-31001);

    const ok = await rpc(provider, 'CheckPerformTransaction', {
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'pay_1' },
    });
    expect(ok.result).toEqual({ allow: true });

    // Bekor qilingan buyurtma qayta to'lanmaydi
    rows.get('pay_1')!.status = 'cancelled';
    const unavailable = await rpc(provider, 'CheckPerformTransaction', {
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'pay_1' },
    });
    expect(unavailable.error?.code).toBe(-31051);
  });

  it('CheckPerformTransaction — fiskal detail (MXIK sozlangan bo‘lsa)', async () => {
    const { provider, rows } = makeProvider({
      PAYME_FISCAL_MXIK: '10899002001000000',
      PAYME_FISCAL_PACKAGE_CODE: '1234567',
      PAYME_FISCAL_VAT_PERCENT: 12,
    });
    seedPayment(rows);
    const ok = await rpc(provider, 'CheckPerformTransaction', {
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'pay_1' },
    });
    expect(ok.result?.allow).toBe(true);
    const detail = ok.result?.detail as {
      receipt_type: number;
      items: Array<Record<string, unknown>>;
    };
    expect(detail.receipt_type).toBe(0);
    expect(detail.items[0]).toMatchObject({
      title: 'Standart',
      price: AMOUNT_TIYIN,
      count: 1,
      code: '10899002001000000',
      package_code: '1234567',
      vat_percent: 12,
    });
  });

  it("to'liq hayot sikli: Create → Create(takror) → Perform → Perform(takror) → Check → Cancel(-2)", async () => {
    const { provider, rows, paymentsService } = makeProvider();
    seedPayment(rows);
    const account = { payment_id: 'pay_1' };

    const created = await rpc(provider, 'CreateTransaction', {
      id: 'txn_A',
      time: Date.now(),
      amount: AMOUNT_TIYIN,
      account,
    });
    expect(created.result?.state).toBe(1);
    expect(created.result?.transaction).toBe('pay_1');
    const createTime = created.result?.create_time as number;
    expect(rows.get('pay_1')!.externalId).toBe('txn_A');

    // Takror (Payme retry) — xuddi shu create_time
    const again = await rpc(provider, 'CreateTransaction', {
      id: 'txn_A',
      time: Date.now(),
      amount: AMOUNT_TIYIN,
      account,
    });
    expect(again.result?.create_time).toBe(createTime);
    expect(again.result?.state).toBe(1);

    // Shu buyurtmaga BOSHQA tranzaksiya — rad
    const other = await rpc(provider, 'CreateTransaction', {
      id: 'txn_B',
      time: Date.now(),
      amount: AMOUNT_TIYIN,
      account,
    });
    expect(other.error?.code).toBe(-31051);

    // Perform
    const performed = await rpc(provider, 'PerformTransaction', {
      id: 'txn_A',
    });
    expect(performed.result?.state).toBe(2);
    const performTime = performed.result?.perform_time as number;
    expect(paymentsService.markPaymentSuccess).toHaveBeenCalledTimes(1);
    expect(rows.get('pay_1')!.status).toBe('success');

    // Perform takror — idempotent, xuddi shu perform_time
    const performedAgain = await rpc(provider, 'PerformTransaction', {
      id: 'txn_A',
    });
    expect(performedAgain.result?.perform_time).toBe(performTime);
    expect(paymentsService.markPaymentSuccess).toHaveBeenCalledTimes(1);

    // To'langan buyurtmaga CreateTransaction — rad
    const afterPaid = await rpc(provider, 'CreateTransaction', {
      id: 'txn_A',
      time: Date.now(),
      amount: AMOUNT_TIYIN,
      account,
    });
    expect(afterPaid.error?.code).toBe(-31008);

    // CheckTransaction
    const check = await rpc(provider, 'CheckTransaction', { id: 'txn_A' });
    expect(check.result).toMatchObject({
      create_time: createTime,
      perform_time: performTime,
      cancel_time: 0,
      transaction: 'pay_1',
      state: 2,
      reason: null,
    });

    // Cancel bajarilgandan keyin → -2, obuna bekor
    const cancelled = await rpc(provider, 'CancelTransaction', {
      id: 'txn_A',
      reason: 5,
    });
    expect(cancelled.result?.state).toBe(-2);
    expect(paymentsService.markPaymentCancelled).toHaveBeenCalledTimes(1);

    // Cancel takror — idempotent
    const cancelledAgain = await rpc(provider, 'CancelTransaction', {
      id: 'txn_A',
      reason: 5,
    });
    expect(cancelledAgain.result?.state).toBe(-2);
    expect(cancelledAgain.result?.cancel_time).toBe(
      cancelled.result?.cancel_time,
    );
    expect(paymentsService.markPaymentCancelled).toHaveBeenCalledTimes(1);

    // Perform bekor qilinganga → -31008
    const performCancelled = await rpc(provider, 'PerformTransaction', {
      id: 'txn_A',
    });
    expect(performCancelled.error?.code).toBe(-31008);
  });

  it('Cancel bajarilmagan tranzaksiya → -1, to‘lov cancelled', async () => {
    const { provider, rows, paymentsService } = makeProvider();
    seedPayment(rows);
    await rpc(provider, 'CreateTransaction', {
      id: 'txn_A',
      time: Date.now(),
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'pay_1' },
    });
    const cancelled = await rpc(provider, 'CancelTransaction', {
      id: 'txn_A',
      reason: 3,
    });
    expect(cancelled.result?.state).toBe(-1);
    expect(rows.get('pay_1')!.status).toBe('cancelled');
    expect(paymentsService.markPaymentCancelled).not.toHaveBeenCalled();
  });

  it('CreateTransaction takrori 12 soatdan keyin → timeout (-31008, reason 4)', async () => {
    const { provider, rows } = makeProvider();
    seedPayment(rows, {
      externalId: 'txn_old',
      providerData: {
        payme: {
          transactionId: 'txn_old',
          state: 1,
          createTime: Date.now() - 13 * 60 * 60 * 1000,
          performTime: 0,
          cancelTime: 0,
          reason: null,
        },
      },
    });
    const r = await rpc(provider, 'CreateTransaction', {
      id: 'txn_old',
      time: Date.now(),
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'pay_1' },
    });
    expect(r.error?.code).toBe(-31008);
    const row = rows.get('pay_1')!;
    expect(row.status).toBe('failed');
    expect(
      (row.providerData as { payme: { state: number; reason: number } }).payme,
    ).toMatchObject({
      state: -1,
      reason: 4,
    });

    // Perform ham -31008
    const p = await rpc(provider, 'PerformTransaction', { id: 'txn_old' });
    expect(p.error?.code).toBe(-31008);
  });

  it("noma'lum tranzaksiya → -31003", async () => {
    const { provider } = makeProvider();
    for (const m of [
      'PerformTransaction',
      'CancelTransaction',
      'CheckTransaction',
    ]) {
      const r = await rpc(provider, m, { id: 'ghost' });
      expect(r.error?.code).toBe(-31003);
    }
  });

  it('GetStatement — create_time bo‘yicha filtr, vaqt tartibida', async () => {
    const { provider, rows } = makeProvider();
    const now = Date.now();
    const mk = (id: string, createTime: number) =>
      seedPayment(rows, {
        id,
        externalId: `txn_${id}`,
        createdAt: new Date(createTime - 60_000), // checkout tranzaksiyadan oldin
        providerData: {
          payme: {
            transactionId: `txn_${id}`,
            state: 2,
            createTime,
            performTime: createTime + 1000,
            cancelTime: 0,
            reason: null,
          },
        },
      });
    mk('p_late', now - 1_000);
    mk('p_early', now - 5_000);
    mk('p_out', now - 100_000);

    const r = await rpc(provider, 'GetStatement', {
      from: now - 10_000,
      to: now,
    });
    const txns = r.result?.transactions as Array<Record<string, unknown>>;
    expect(txns.map((t) => t.id)).toEqual(['txn_p_early', 'txn_p_late']);
    expect(txns[0]).toMatchObject({
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'p_early' },
      transaction: 'p_early',
      state: 2,
    });
  });

  it("CheckPerformTransaction — buyurtmada FAOL tranzaksiya bo'lsa (sandbox «В процессе») → -31051", async () => {
    const { provider, rows } = makeProvider();
    seedPayment(rows);
    await rpc(provider, 'CreateTransaction', {
      id: 'txn_A',
      time: Date.now(),
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'pay_1' },
    });
    const r = await rpc(provider, 'CheckPerformTransaction', {
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'pay_1' },
    });
    expect(r.error?.code).toBe(-31051);
    expect(r.error?.data).toBe('payment_id');
  });

  it("SetFiscalData — PERFORM/CANCEL saqlanadi, topilmasa -32001, noto'g'ri params -32602", async () => {
    const { provider, rows } = makeProvider();
    seedPayment(rows);
    await rpc(provider, 'CreateTransaction', {
      id: 'txn_F',
      time: Date.now(),
      amount: AMOUNT_TIYIN,
      account: { payment_id: 'pay_1' },
    });
    await rpc(provider, 'PerformTransaction', { id: 'txn_F' });

    const perform = await rpc(provider, 'SetFiscalData', {
      id: 'txn_F',
      type: 'PERFORM',
      fiscal_data: {
        receipt_id: 121,
        status_code: 0,
        fiscal_sign: '800031554082',
      },
    });
    expect(perform.result).toEqual({ success: true });

    const cancel = await rpc(provider, 'SetFiscalData', {
      id: 'txn_F',
      type: 'CANCEL',
      fiscal_data: {
        receipt_id: 123,
        status_code: 0,
        fiscal_sign: '900031555055',
      },
    });
    expect(cancel.result).toEqual({ success: true });

    const st = (
      rows.get('pay_1')!.providerData as {
        payme: {
          state: number;
          fiscal: { perform_data: unknown; cancel_data: unknown };
        };
      }
    ).payme;
    expect(st.state).toBe(2);
    expect(st.fiscal.perform_data).toMatchObject({ receipt_id: 121 });
    expect(st.fiscal.cancel_data).toMatchObject({ receipt_id: 123 });

    const ghost = await rpc(provider, 'SetFiscalData', {
      id: 'ghost',
      type: 'PERFORM',
      fiscal_data: { receipt_id: 1 },
    });
    expect(ghost.error?.code).toBe(-32001);

    const bad = await rpc(provider, 'SetFiscalData', {
      id: 'txn_F',
      type: 'WAT',
    });
    expect(bad.error?.code).toBe(-32602);

    // Fiskal ma'lumot CheckTransaction javobiga ta'sir qilmaydi
    const chk = await rpc(provider, 'CheckTransaction', { id: 'txn_F' });
    expect(chk.result?.state).toBe(2);
  });
});
