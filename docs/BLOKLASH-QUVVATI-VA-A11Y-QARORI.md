# Bloklash quvvati va Accessibility qarori (bola ilovasi)

> **Bu hujjat kim uchun:** loyihada ishlaydigan keyingi dasturchi yoki AI uchun.
> Bu yerda bloklash HAQIQATDA nima qila oladi, nima qila OLMAYDI, va Google Play
> bo'yicha hali **qaror qilinmagan** masala yozilgan.
>
> To'ldiruvchi hujjat: `docs/PLAY_STORE_CHECKLIST.md` (Console'ni to'ldirish
> bo'yicha qadamlar). Bu fayl esa **texnik quvvat va xavf** haqida.
>
> Holat: 2026-07-26 · Commitlar: `2ef9cb7`, `368a10e` · Faqat `farzandim_child/`
> (ota-ona ilovasi `Farzandim/` **tegilmagan**).

---

## 0) ⛔ HECH QACHON BUZMANG (regressiya qilmang)

Quyidagilar ataylab shunday qilingan. "Soddalashtiraman" deb o'zgartirilsa —
xavfsizlik teshigi yoki qurilmani ishlatib bo'lmas holga keltirish xavfi.

| Qoida | Nega |
|---|---|
| Repolar tarmoq xatosida **`null`** qaytaradi, bo'sh ro'yxat EMAS | Bo'sh ro'yxat = "blok yo'q" deb tushunilib prefs tozalanardi → **aviarejim = to'liq bypass** |
| `*` (wildcard) accessibility'da **HOME bosmaydi** | HOME → launcher ochiladi → launcher ham `*` bilan bloklanadi → **cheksiz HOME sikli**, qurilma ishlatib bo'lmas holga tushadi (va o'chirish taqiqlangani uchun tiklab ham bo'lmaydi) |
| `com.android.settings` **hech qachon bloklanmaydi** | Aks holda na bola, na ota-ona, na qo'llab-quvvatlash qurilmani tiklay olmaydi |
| `getTodayUsageMs()` accessibility oqimidan **chaqirilmaydi** | U kun boshidan barcha usage hodisalarini aylanadi; accessibility callback ilova bosh oqimida ishlaydi → butun tizim UI'si qotadi |
| O'yin aniqlash (APK ZIP skani) accessibility'ga **chiqarilmaydi** | Bir marta ANR keltirgan, ataylab alohida oqimga olingan |
| `isAccessibilityTool="false"` | Kuzatuv ilovalari bu bayroqqa **haqli emas**. `true` qo'yish = qasddan aldash = akkaunt to'xtatilishi |
| Overlay faqat `RestrictionService` tomonidan qo'shiladi | `showOverlay()` ichida `hideOverlay()` + `addView()` sinxronlanmagan — ikki chaqiruvchi bo'lsa view ikki marta qo'shilib xato beradi |
| Accessibility `_allGranted`ga **qo'shilmagan** | Ilgari ixtiyoriy ruxsatni majburiy qilish foydalanuvchini ruxsat ekranida **qamab qo'ygan** (mavjud izohda yozilgan) |

---

## 1) Bloklash HAQIQATDA nimaga qodir (halol baho)

### 1.1 Internetsiz ishlashi — ✅ TO'LIQ HAL QILINDI

**Ilgari (xato):** bola aviarejimni yoqsa **~15 soniyada barcha bloklar o'chardi**.
Sabab: `backend_*_repository.dart` tarmoq xatosida `const []` qaytarardi,
`restrictions_sync_service.dart` esa uni "ota-ona hech narsani bloklamagan" deb
tushunib `blocked_packages` ni bo'sh string bilan qayta yozardi. Ikkala
izolyatda ham — UI'ni yopish yordam bermasdi.

**Endi:** `null` = "bilmayman" → sync prefs'ga **umuman tegmaydi**.

- Bloklar internetsiz **cheksiz** ishlayveradi (native prefs'dan o'qiydi)
- ⚠️ Nozik jihat: internet yo'q bo'lsa ota-ona **blokni yechsa ham** bola
  ko'rmaydi (internet qaytguncha). Bu **ataylab** — xavfsizlik tomonga og'ish.
  Qo'llab-quvvatlashga shikoyat kelishi mumkin, javob: "bu himoya".

### 1.2 "Ilovaga umuman kirib bo'lmasin" — ⚠️ QISMAN

| | Holat |
|---|---|
| Bola interaktiv ekrangacha yetib bormaydi | ✅ (accessibility yoqilsa ~0.1s) |
| Ilova **o'ldiriladi** | ❌ HOME faqat orqaga suradi. Haqiqiy to'xtatish `DevicePolicyManager.setPackagesSuspended` — u **Device Owner** talab qiladi (zavod holatiga qaytarib o'rnatish), Play orqali o'rnatiladigan ilova bunga **ega bo'la olmaydi** |
| Bola xizmatni o'chira oladi | ⚠️ Ha (Sozlamalar ochiq qoldirilgan — yuqoridagi jadvalga qarang) |
| MIUI/EMUI "tozalagich" xizmatni o'chirib qo'yishi | ⚠️ Ha — shuning uchun UsageStats poll'i **doim yoqiq qolishi shart** |
| Second Space / Dual Apps / Secure Folder | ❌ **Yopilmagan teshik** |

### 1.3 Telegram/VoIP qo'ng'iroq — ❌ HALI QILINMAGAN (sabab aniqlangan)

**Nega overlay ishlamaydi (tuzatib bo'lmaydigan tuzilmaviy sabab):**
AOSP oyna qatlamlari — `TYPE_APPLICATION_OVERLAY` = **11-qatlam**,
`TYPE_NOTIFICATION_SHADE` (kiruvchi qo'ng'iroqning "Javob berish" tugmasi
chiziladigan joy) = **17-qatlam**. Overlay uni **hech qachon yopa olmaydi**.
Bundan tashqari `queryEvents` qo'ng'iroqni umuman ko'rmaydi — `CallStyle`
bildirishnomasi hech qanday activity ochmaydi.

**Yagona ishlaydigan yechim:** `NotificationListenerService` →
bildirishnomaning **o'z `EXTRA_DECLINE_INTENT`** ini yuborish. Shunda qo'ng'iroq
haqiqatan uziladi va ilova o'z ovozini o'zi to'xtatadi.

**Nega hali qilinmadi (ataylab):**
- ⚠️ **`notification.actions[0]` ni ishlatmang!** Agar `actions[0]` "Javob
  berish" bo'lsa — qo'ng'iroqni rad etish o'rniga **avtomatik javob berib
  yuborasiz**. Bu falokatli teskari xulq.
- Telegram manbadan tasdiqlangan (`VoIPPreNotificationService`, kanal
  `incoming_calls4<N>`). **WhatsApp yopiq kodli — tekshirilmagan.**
  Haqiqiy qurilmada `extras.keySet()` va `getInt("android.callType")` ni
  loglab tasdiqlamasdan chiqarmang.
- `cancelNotification()` ga **ishonmang** — AOSP uni `FLAG_ONGOING_EVENT`
  bo'lsa jimgina bajarmaydi (WhatsApp uslubidagi FGS bildirishnomalarida).
- Qo'ng'iroq hodisasida **foreground service ochmang** — Android 15
  (targetSdk 35) da `ForegroundServiceStartNotAllowedException` beradi.

**Qoladigan kamchilik:** ~200-600 ms jiringlash baribir chiqadi (bildirishnoma
post qilinishidan OLDIN ushlaydigan API yo'q). Nol-jiringlash faqat Device
Owner'da.

### 1.4 Qimor ilovalari — ⚠️ QISMAN, HALI QILINMAGAN

Aniqlash mumkin: (a) qo'lda tuzilgan paket ro'yxati, (b) `installSource`
(O'zbekistonda qimor ilovalari asosan Play'dan **tashqari** o'rnatiladi —
eng kuchli signal, lekin **hozir bola qurilmasi uni umuman yubormaydi**),
(c) nom bo'yicha evristika.

**Aniqlab bo'lmaydigan:** brauzerdagi qimor, Telegram botlar, nomini ham
paket ID'sini ham yashirgan APK'lar.

⚠️ **Backend xatosi (tuzatilmagan):** `installed-apps.service.ts:126` da
`app.category ?? classifyPackage(...)` — ya'ni manifestida `appCategory="game"`
deb yozilgan qimor ilovasi GAME sifatida qayd etiladi va qimor tekshiruvi
**umuman ishlamaydi**.

⚠️ Kalit so'z qidiruvida **`includes()` ishlatmang**, faqat so'z-chegarali
regex: `bet` → `alphabet`, `diabetes`, `BetterMe`, `.beta` ga mos keladi;
`pari` — o'zbekcha oddiy so'z; lotincha `vulkan` — grafika API (faqat kirillcha
`вулкан` kazino).

**Marketing tili:** hech qachon "qimorni bloklaydi" demang. "Bet ilovalarini
bloklaydi va sizga darhol xabar beradi" deng.

---

## 2) ⏳ QAROR QILINMAGAN: Accessibility'ni Play'ga yuborish

Kod **yozilgan va uxlab yotibdi** — foydalanuvchi yoqmaguncha hech narsa
o'zgarmaydi. Egasi (Ziyodillokh) **hali qaror qilmagan**.

### 2.1 Rad etilsa nima bo'ladi

| Bo'ladi | BO'LMAYDI |
|---|---|
| O'sha reliz chiqmaydi, sabab yoziladi | ❌ Ilova o'chirilmaydi |
| Tuzatib qayta yuboriladi (urinish cheksiz) | ❌ Akkaunt bloklanmaydi |
| Jonli versiya ishlab turaveradi | ❌ Ota-ona ilovasiga ta'sir yo'q |

**Rad etish (rejection) ≠ to'xtatish (suspension).** To'xtatish qasddan
aldash yoki takroriy qoidabuzarlikda bo'ladi.

### 2.2 Yashirin xavf

Cheklangan ruxsat deklaratsiyasi **to'liq qayta ko'rikni** ishga tushiradi —
tekshiruvchi `QUERY_ALL_PACKAGES`, fon joylashuvi va Data Safety'ni ham
qaytadan ko'radi. Rad javobi **boshqa sabab bilan** kelishi mumkin.

### 2.3 Tavsiya etilgan yo'l — 2 bosqich

1. **Avval accessibility'SIZ chiqaring.** Bloklash baribir ishlaydi (1-3 s
   kechikish bilan), va internet-bypass tuzatilgani baribir kuchda qoladi.
2. **Tasdiqlangach, alohida yangilanish sifatida qo'shing.** Rad etilsa —
   jonli ilova ishlab turaveradi, faqat yangilanish chiqmaydi.

### 2.4 O'chirish (rollback) — aniq 2 joy

```
1. farzandim_child/android/app/src/main/AndroidManifest.xml
   → <service android:name=".BlockAccessibilityService"> blokini o'chirish

2. farzandim_child/lib/features/permissions/presentation/screens/
   permission_setup_screen.dart
   → 'permissionSetup.a11yName' li _PermRow ni o'chirish
     (foydalanuvchi ishlamaydigan tugmani ko'rmasin)
```

Qolgani **o'zidan-o'zi passiv**: manifestda e'lon qilinmagan servisni Android
ishga tushirmaydi, `a11yPkg` abadiy `null` qoladi, `RestrictionService` esa
eski yo'l (UsageStats) bilan ishlayveradi. Kotlin fayllarni o'chirish shart emas.

### 2.5 Deklaratsiya matni (rad etilmaslik uchun muhim)

❌ **Yozmang:** "foreground ilovani aniqlash uchun" — tekshiruvchi
"UsageStats bor-ku" deb **torroq API** talab qilib rad etadi.

✅ **Yozing (taxminan):**
> "UsageStats polling misses blocks for up to a second and is throttled by OEM
> battery managers. The accessibility service provides supplementary low-latency
> detection so a parent-blocked app closes immediately. It does not read screen
> content (`canRetrieveWindowContent=false`)."

Qo'shimcha majburiy narsalar:
- Do'kon tavsifida (uz/ru/en) accessibility ishlatilishini **yozish** — buni
  tashlab ketish alohida qoidabuzarlik
- Ko'rik videosi **oshkora tushuntirish ekranining o'zini** ko'rsatishi kerak
- Oldindan bog'langan test akkaunt berish
- **Shoshilinch reliz bilan birga jo'natmang** — 1-2 marta qayta yuborishga
  tayyor turing

---

## 3) 🔴 Ochiq blokerlar (kod bilan hal qilinmaydi)

### 3.1 Bola ilovasining Firebase konfiguratsiyasi noto'g'ri — BUILD YIQILADI

`applicationId` = `com.farzandim.growth`, lekin
`config/firebase/child/google-services.child.json` hali **eski**
`com.farzandim.child` ni o'z ichiga oladi.

```
> No matching client found for package name 'com.farzandim.growth'
```

CI'dagi tekshiruv (`build-child-aab.yml`) ham buni ushlaydi va yiqiladi.

**Hal qilish (faqat qo'lda):** Firebase Console → loyihaga **yangi Android
ilova** qo'shish (`com.farzandim.growth`) → yangi `google-services.json` ni
yuklab olib, `config/firebase/child/google-services.child.json` ni almashtirish.
SHA-1 barmoq izlarini ham qo'shishni unutmang.

### 3.2 Play deklaratsiyalari
`docs/PLAY_STORE_CHECKLIST.md` ga qarang.

---

## 4) Keyingi ish (bajarilmagan, ustuvorlik tartibida)

| # | Ish | Xavf | Izoh |
|---|---|---|---|
| 1 | Firebase konfiguratsiyasi (3.1) | — | **Bloker**, qo'lda |
| 2 | VoIP qo'ng'iroq (`NotificationListenerService`) | MED | WhatsApp'ni avval qurilmada tekshirish shart |
| 3 | Jadval oynalarini native'da hisoblash | MED-HIGH | Hozir Dart'da; offline'da oyna **boshlanmaydi/tugamaydi**. Shuningdek `_isInWindow` da xato: dushanba-only 22:00–06:00 oynasi seshanba emas, **dushanba** 00:00–06:00 ni bloklaydi |
| 4 | Grant (qo'shimcha vaqt) muddati | MED | Fail-closed'dan keyin offline grant **abadiy** qolib ketishi mumkin — backend `expiresAt` kontrakti kerak |
| 5 | Qimor kategoriyasi | MED | Ro'yxatni **remote config** qiling — klonlar reliz tezligidan tez chiqadi |

---

## 5) Fayl xaritasi (bu ishda tegilganlar)

```
farzandim_child/
├── android/app/src/main/
│   ├── AndroidManifest.xml            isMonitoringTool + a11y servis
│   ├── res/values/strings.xml         YANGI (a11y tavsifi — majburiy)
│   ├── res/xml/accessibility_service_config.xml  YANGI
│   └── kotlin/.../
│       ├── BlockPolicy.kt             YANGI — holatsiz qaror
│       ├── BlockAccessibilityService.kt  YANGI — tez blok
│       ├── RestrictionService.kt      instance + a11yPkg ilgagi, SHOW_WHEN_LOCKED
│       └── UsageStatsPlugin.kt        isAccessibilityEnabled TUZATILDI (doim false edi)
├── lib/features/
│   ├── app_restrictions/data/repositories/backend_app_limit_repository.dart  null
│   ├── app_restrictions/data/services/restrictions_sync_service.dart  FAIL-CLOSED
│   ├── schedules/data/repositories/backend_{schedule,routine}_repository.dart  null
│   └── permissions/presentation/screens/
│       ├── accessibility_disclosure_screen.dart  YANGI (Play majburiy)
│       └── permission_setup_screen.dart          ixtiyoriy qator
└── assets/translations/{uz,ru,en}.json  a11yDisclosure.* + permissionSetup.a11yName
```
