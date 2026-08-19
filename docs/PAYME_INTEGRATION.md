# Payme obuna to'lovi — ulash qo'llanmasi

Click yoniga **Payme** (Merchant API, JSON-RPC) ulandi. Kod tayyor; ishga
tushirish uchun **serverdagi `.env`** va **Payme kabineti** sozlanadi.

| Nima                 | Qiymat                                              |
|----------------------|-----------------------------------------------------|
| Kassa ID (merchant)  | `6a7dc4613febcfd2f87a9eb9`                          |
| Webhook (endpoint)   | `https://farzandimedu.uz/api/payments/webhook/payme` |
| Test checkout        | `https://checkout.test.paycom.uz`                   |
| Jonli checkout       | `https://checkout.paycom.uz` (default, env bo'sh)   |
| Sandbox (tekshiruv)  | `https://test.paycom.uz` (Payme kabineti → Sinov)   |

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
PAYME_CHECKOUT_URL=https://checkout.test.paycom.uz
PAYME_ACCOUNT_FIELD=payment_id
```

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

## 3. Payme kabinetida (merchant egasi qiladi)

1. **Kassa → Endpoint URL**: `https://farzandimedu.uz/api/payments/webhook/payme`
2. **Sinov (test.paycom.uz)**: endpoint + TEST kalit + test `account` qiymati
   bilan avtomatik testlar ishga tushiriladi. `account.payment_id` sifatida
   **haqiqiy `pending` Payment id** kerak — uni olish:
   - ilovada Premium → Payme tanlab checkout oching (serverda test kalit,
     test checkout bo'lishi kerak) — `Payment` yozuvi yaratiladi, yoki
   - admin panel → Monetizatsiya → To'lovlar'dan `payme` + `pending`
     yozuv id'si, yoki
   - `POST /api/payments/checkout` (ota-ona JWT bilan) javobidagi `paymentId`.

   Summa = tarif narxi × 100 (tiyin): oylik 29 000 so'm → `2900000`.
   **Har test seriyasi uchun yangi payment_id** ishlating — to'langan/bekor
   qilingan buyurtma qayta to'lanmaydi (`-31051`), bu to'g'ri xatti-harakat.
3. Sandbox hamma testlardan o'tgach Payme kassani **faollashtiradi** →
   2b bo'yicha production kalitga o'ting.

Test kartalar (sandbox checkout): `8600 0691 9540 6311`, `03/99`, SMS `666666`
(Payme hujjatidan; o'zgargan bo'lsa kabinetdagi "Тестовые карты"ga qarang).

---

## 4. Tekshirish (serverda / lokal)

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

## 5. Xato kodlari (biz qaytaradiganlar)

| Kod      | Ma'no                                                     |
|----------|-----------------------------------------------------------|
| -31001   | Summa noto'g'ri (`amount` ≠ `Payment.amount × 100`)       |
| -31003   | Tranzaksiya topilmadi (`params.id`)                       |
| -31008   | Bajarib bo'lmaydi (bekor qilingan / 12 soat o'tgan)       |
| -31050   | Buyurtma topilmadi (`account.<field>`)                    |
| -31051   | Buyurtma to'lanmaydi (to'langan / bekor / boshqa tranzaksiya ochiq) |
| -32504   | Avtorizatsiya xato (kalit mos emas)                       |
| -32601   | Metod topilmadi                                           |

Holatlar: `1` yaratilgan, `2` bajarilgan, `-1` bekor (bajarilmasdan),
`-2` bekor (bajarilgandan keyin → obuna ham bekor qilinadi).

---

## 6. Fiskalizatsiya (ixtiyoriy, keyinroq)

`PAYME_FISCAL_MXIK` + `PAYME_FISCAL_PACKAGE_CODE` (+ `PAYME_FISCAL_VAT_PERCENT`)
to'ldirilsa `CheckPerformTransaction` javobiga soliq cheki uchun `detail`
qo'shiladi. Ikkalasi ham bo'lmasa `detail` umuman yuborilmaydi.
