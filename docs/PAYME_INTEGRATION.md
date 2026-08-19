# Payme obuna to'lovi — ulash qo'llanmasi

Click yoniga **Payme** (Merchant API, JSON-RPC) ulandi. Kod tayyor; ishga
tushirish uchun **serverdagi `.env`** va **Payme kabineti** sozlanadi.

| Nima                 | Qiymat                                              |
|----------------------|-----------------------------------------------------|
| Kassa ID (merchant)  | `6a7dc4613febcfd2f87a9eb9`                          |
| Webhook (endpoint)   | `https://farzandimedu.uz/api/payments/webhook/payme` |
| Checkout (jonli)     | `https://checkout.paycom.uz` (default, env bo'sh)   |
| Sandbox (tekshiruv)  | `https://test.paycom.uz` (Merchant API testlari)    |

> ⚠️ **`checkout.test.paycom.uz` ISHLATILMAYDI** — bizning kassa test
> muhitida mavjud emas (2026-08-19 tekshirildi: test checkout ham, prod
> checkout ham hozircha «Поставщик не найден или заблокирован» / ilovada
> «Tashkilot hisobi topilmadi» deydi). Test kalit faqat **sandbox'dagi
> Merchant API testlari** bizning webhook'ni chaqirishi uchun.

Kalitlar (test va production) Payme hodimi tomonidan berilgan — ular bu
hujjatda **yozilmaydi**; serverdagi `.env`da turadi.

---

## 1. Oqim (qisqacha)

1. Ota-ona ilovasi: Sozlamalar → **Premium** → tarif → **Ulanish**.
   Backend `GET /api/payments/plans` → `availableProviders` ichida `payme`
   bo'lsa va `click` ham bo'lsa — **to'lov usuli tanlash** varag'i (Click /
   Payme). Bittasi bo'lsa darhol o'sha ochiladi.
2. `POST /api/payments/checkout {provider:'payme', planId, billingPeriod}` →
   `checkoutUrl` = `PAYME_CHECKOUT_URL/<base64(m=…;ac.payment_id=…;a=…)>`
   (summa **tiyinda**). Ilova uni brauzerda ochadi.
3. Payme bizning webhook'ga JSON-RPC chaqiradi:
   `CheckPerformTransaction → CreateTransaction → PerformTransaction`
   (bekor: `CancelTransaction`; tekshiruv: `CheckTransaction`, `GetStatement`).
   `PerformTransaction` obunani faollashtiradi (`PaymentsService.markPaymentSuccess`).
4. Ilovaga qaytilganda (`AppLifecycleState.resumed`) tarif yangilanadi.

Kod: `backend/src/modules/payments/providers/payme.provider.ts`
(test: `payme.provider.spec.ts`), UI: `Farzandim/lib/features/settings/presentation/screens/parvoz_premium_screen.dart`.

---

## 2. Server `.env` (qo'lda! deploy `.env`ni tegmaydi)

`~/new-platform/backend/.env` ga qo'shing, so'ng
`sudo systemctl restart farzandim-v2-backend.service`.

### 2a. Sinov bosqichi (Payme sandbox tekshiruvi o'tguncha)

```env
PAYME_MERCHANT_ID=6a7dc4613febcfd2f87a9eb9
PAYME_MERCHANT_KEY=<TEST kalit>
PAYME_CHECKOUT_URL=
PAYME_ACCOUNT_FIELD=payment_id
```

Bu bosqichda ilovadan Payme tanlansa checkout sahifasi **hali ochilmaydi**
(kassa faol emas) — bu normal. Sinov = Payme sandbox'i (test.paycom.uz)
bizning webhook'ni test kalit bilan tekshiradi (3-bo'lim).

### 2b. Jonli ishga o'tish (Payme kassani faollashtirgach)

```env
PAYME_MERCHANT_ID=6a7dc4613febcfd2f87a9eb9
PAYME_MERCHANT_KEY=<PRODUCTION kalit>
PAYME_CHECKOUT_URL=
PAYME_ACCOUNT_FIELD=payment_id
```

> ⚠️ **Bir vaqtda FAQAT BITTA kalit.** Sandbox (test.paycom.uz) so'rovlarni
> TEST kalit bilan, jonli Payme — PRODUCTION kalit bilan yuboradi. Kalit
> mos kelmasa webhook `-32504 Authorization failed` qaytaradi (bu normal,
> protokolga mos). Test kalitini jonli serverda qoldirmang — uni bilgan odam
> to'lamasdan obuna yozdirishi mumkin.

### 2c. `PAYME_ACCOUNT_FIELD` nima?

Payme kabinetida kassa yaratilganda "Счёт / Account" maydonlari belgilanadi
(masalan `payment_id`, `order_id`). Biz buyurtma identifikatorini aynan shu
nom bilan uzatamiz (`ac.<nom>=…`) va webhook'da `params.account.<nom>`dan
o'qiymiz. **Kassada qaysi nom bo'lsa — shu yerga yozing.** Default
`payment_id`. Payme hodimidan so'rang yoki kabinet → Kassa → Настройки →
Поля счёта'da ko'ring.

### 2d. IP allowlist (`PAYMENT_WEBHOOK_IPS`)

Bu env **barcha** webhook'larga (Click, Payme, Uzum) qo'llanadi. Agar prod'da
to'ldirilgan bo'lsa (Click IP'lari), **Payme IP'larini ham qo'shing**, aks
holda Payme so'rovlari 403 bo'ladi. Payme hujjatidagi manzillar:
`185.234.113.1`–`185.234.113.15` (vergul bilan, diapazonsiz — har bir IP
alohida). Bo'sh qoldirilsa IP tekshirilmaydi (imzo/kalit baribir tekshiriladi).

---

## 3. Sandbox (test.paycom.uz) — rasmiy hujjat bo'yicha qanday ishlaydi

Manba: developer.help.paycom.uz/pesochnitsa + sandbox interfeysi matni.

- **Kirish:** https://test.paycom.uz → «Введите Merchant ID» (bizning kassa ID
  `6a7dc4613febcfd2f87a9eb9`) → «Какой ключ использовать?» → **TEST_KEY** →
  test kalitni kiritish. Sandbox alohida test-kassa TALAB QILMAYDI — ayni
  production kassa ID ishlatiladi, faqat avtorizatsiya TEST_KEY bilan.
  Endpoint URL kassa sozlamalaridan olinadi (Payme Business → Kassa →
  Endpoint URL = `https://farzandimedu.uz/api/payments/webhook/payme`).
- **Test parametrlari** (chap panel): *Тип счёта* = **Одноразовый** (bir
  martalik — bizniki shunday, `payment_id` bir marta to'lanadi);
  *Текущий статус счёта* va *Текущее состояние транзакции* — tester DB
  holatiga mos qilib tanlaydi. Kutilgan javoblar:

  | Holat (sandbox'da tanlanadi) | Bizning DB | Kutilgan javob | Bizniki |
  |---|---|---|---|
  | Ожидает оплаты | `pending`, tranzaksiya yo'q | CheckPerform `allow:true`, Create → yangi tranzaksiya | ✅ |
  | В процессе (boshqa tranzaksiya band qilgan) | state=1 bor | -31050..-31099 | ✅ -31051 |
  | Заблокирован (to'langan/bekor) | `success`/`cancelled` | -31050..-31099 | ✅ -31051 |
  | Не существует | id yo'q | -31050..-31099 | ✅ -31050 |
  | Неверная авторизация | — | -32504 | ✅ |
  | Неверная сумма | — | -31001 | ✅ |
  | Create/Perform/Cancel ikki marta | — | ikkinchi javob birinchisi bilan bir xil | ✅ |
  | Cancel state 1 → -1, state 2 → -2 | — | reason bilan | ✅ |
  | GetStatement, CheckTransaction | — | spetsifikatsiya formati | ✅ |
  | ChangePassword | — | 3 keys (parol almashtirish) | ❌ -32601 (ixtiyoriy; kalit env'da, runtime'da o'zgarmaydi) |

- **Har ssenariy uchun YANGI `payment_id`** (pending) ishlating: 1-ssenariy
  (Create→Cancel) buyurtmani `cancelled` qiladi, 2-ssenariy (Create→Perform)
  uchun yangi pending buyurtma kerak — aks holda «Заблокирован» → -31051
  (bu to'g'ri javob, lekin ssenariy o'tmaydi).
- **Chek-havola tekshiruvi:** `https://test.paycom.uz/<base64>` sandbox'da
  bizning checkout havolamizni PARSE qilib ko'rsatadi (m, ac.payment_id, a) —
  to'lov sahifasi emas, faqat format tekshiruvi. Kerak bo'lsa vaqtincha
  `PAYME_CHECKOUT_URL=https://test.paycom.uz` qo'yib ilovadan havola oling.
- **Rasmiy IP'lar** (webhook faqat shulardan keladi): 185.234.113.1 … 185.234.113.15.
- `SetFiscalData` (ixtiyoriy; fiskalizatsiya yoqilgan kassada to'lov/bekordan
  keyin Payme chaqiradi) — implement qilingan: `{success:true}`, ma'lumot
  `providerData.payme.fiscal`ga yoziladi.

## 4. Payme kabinetida (merchant egasi qiladi)

**Hozirgi holat (2026-08-19):** kassa `6a7dc461…` Payme tomonidan hali
**faollashtirilmagan** — checkout «Поставщик не найден или заблокирован».
Faollashtirish Payme hodimi tomonidan, odatda sandbox testlari o'tgach.
Payme hodimiga yuboriladigan ma'lumot: endpoint
`https://farzandimedu.uz/api/payments/webhook/payme`, account maydoni
`payment_id`, test kalit serverda, sandbox testlarini o'tkazish mumkin.

1. **Kassa → Endpoint URL**: `https://farzandimedu.uz/api/payments/webhook/payme`
2. **Sinov (test.paycom.uz)**: endpoint + TEST kalit + test `account` qiymati
   bilan avtomatik testlar ishga tushiriladi. `account.payment_id` sifatida
   **haqiqiy `pending` Payment id** kerak — uni olish:
   - ilovada Premium → Payme tanlab «Ulanish» bosing — checkout sahifasi
     ochilmasa ham backend'da `Payment` (pending) yaratiladi; id'sini
     admin panel → Monetizatsiya → To'lovlar (`payme` + `pending`) dan oling, yoki
   - `POST /api/payments/checkout` (ota-ona JWT bilan) javobidagi `paymentId`.

   Summa = tarif narxi × 100 (tiyin): 29 000 so'm → `2900000`, 1 000 so'm → `100000`.
   **Har test seriyasi uchun yangi payment_id** ishlating — to'langan/bekor
   qilingan buyurtma qayta to'lanmaydi (`-31051`), bu to'g'ri xatti-harakat.
3. Sandbox hamma testlardan o'tgach Payme kassani **faollashtiradi** →
   2b bo'yicha production kalitga o'ting.

Payme test kartalari (`8600 0691 9540 6311`, `03/99`, SMS `666666`) faqat
sandbox'da ro'yxatdan o'tgan kassa uchun ishlaydi — bizda bunday kassa yo'q,
shuning uchun ilovadan haqiqiy to'lov sinovi kassa faollashgach (production
kalit bilan) qilinadi.

---

## 5. Tekshirish (serverda / lokal)

Webhook tirikmi (kalitsiz → JSON-RPC auth xatosi, **HTTP 200**):

```bash
curl -s -X POST https://farzandimedu.uz/api/payments/webhook/payme \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"CheckPerformTransaction","params":{}}'
# → {"error":{"code":-32504,...},"id":1}
```

Kalit bilan (Basic auth login `Paycom`, parol = kalit):

```bash
AUTH=$(printf 'Paycom:%s' "$PAYME_MERCHANT_KEY" | base64 -w0)
curl -s -X POST https://farzandimedu.uz/api/payments/webhook/payme \
  -H "Authorization: Basic $AUTH" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"CheckPerformTransaction","params":{"amount":2900000,"account":{"payment_id":"<PAYMENT_ID>"}}}'
# → {"result":{"allow":true},"id":1}        (pending + summa to'g'ri)
# → {"error":{"code":-31050,...}}            (payment_id topilmadi)
# → {"error":{"code":-31001,...}}            (summa noto'g'ri)
```

Provayder ilovaga ko'rinadimi: `GET /api/payments/plans` (JWT) →
`availableProviders: ["click","payme"]`.

Unit test: `cd backend && npx jest src/modules/payments/providers/payme.provider.spec.ts`.

---

## 6. Xato kodlari (biz qaytaradiganlar)

| Kod      | Ma'no                                                     |
|----------|-----------------------------------------------------------|
| -31001   | Summa noto'g'ri (`amount` ≠ `Payment.amount × 100`)       |
| -31003   | Tranzaksiya topilmadi (`params.id`)                       |
| -31008   | Bajarib bo'lmaydi (bekor qilingan / 12 soat o'tgan)       |
| -31050   | Buyurtma topilmadi (`account.<field>`)                    |
| -31051   | Buyurtma to'lanmaydi (to'langan / bekor / boshqa tranzaksiya ochiq) |
| -32504   | Avtorizatsiya xato (kalit mos emas)                       |
| -32600   | RPC so'rovda `method` yo'q                                |
| -32601   | Metod topilmadi                                           |
| -32001 / -32602 | SetFiscalData: chek topilmadi / params noto'g'ri    |

Holatlar: `1` yaratilgan, `2` bajarilgan, `-1` bekor (bajarilmasdan),
`-2` bekor (bajarilgandan keyin → obuna ham bekor qilinadi).

---

## 7. Fiskalizatsiya (ixtiyoriy, keyinroq)

`PAYME_FISCAL_MXIK` + `PAYME_FISCAL_PACKAGE_CODE` (+ `PAYME_FISCAL_VAT_PERCENT`)
to'ldirilsa `CheckPerformTransaction` javobiga soliq cheki uchun `detail`
qo'shiladi. Ikkalasi ham bo'lmasa `detail` umuman yuborilmaydi.
