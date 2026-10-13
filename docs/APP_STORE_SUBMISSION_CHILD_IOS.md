# Parvoz Growth (iOS) — App Store topshirish to'plami (LOYIHA)

> **Holat:** loyiha, 2026-10-13, `feat/child-ios`. Bu hujjatdagi har bir
> da'vo joriy kod bilan tekshirilgan (fayl havolalari matn ichida).
> Do'konda ko'rinadigan matnlar (nom, subtitle, promo, tavsif, kalit
> so'zlar, skrinshotlar): `farzandim_child/APP_STORE_LISTING_CHILD.md`.
> Maxfiylik siyosatiga qo'shiladigan iOS bo'limi:
> `docs/PRIVACY_POLICY_IOS_SECTION_DRAFT.md`.
>
> `<<...>>` — EGASI to'ldiradigan joylar. Topshirishdan oldin
> `grep -n "<<" docs/APP_STORE_SUBMISSION_CHILD_IOS.md` hech narsa
> qaytarmasligi kerak (App Store Connect'ga ko'chirilgan nusxada).
>
> Qavs ichidagi `F2`, `F4`... — App Store audit topilmalari raqamlari.

---

## 1. App Review Information (App Store Connect → versiya sahifasi)

| Maydon | Qiymat |
|---|---|
| Sign-in required | **Yes** |
| User name | `<<APPLE_REVIEW_FAMILY_CODE>>` (5 xonali oila kodi) |
| Password | `Family code only — see Notes` |
| Contact first/last name | `<<ISM>>` `<<FAMILIYA>>` |
| Contact phone | `<<+998...>>` |
| Contact email | `<<SUPPORT_EMAIL>>` — §8 F44 qaroriga ko'ra bitta, kuzatiladigan manzil |
| Attachment | ixtiyoriy: Ekran vaqti oqimining videosi (Notes'dagi havola bilan bir xil) |

### Notes (EN — to'ldirib, shu holicha qo'ying; ≤4000 belgi)

Matn placeholder'lar bilan **3 878 belgi**. To'ldirgandan keyin qayta
sanang (`pbpaste | wc -m` yoki python) — 4 000 dan oshmasin.

```text
Parvoz Growth is the companion app of the Parvoz family safety service. A parent installs it on their child's iPhone and pairs it with our parent app "Parvoz Parents" (App Store id6798972223; also on Google Play). No Android device is needed for this review.

DEMO ACCESS
- Family code: <<APPLE_REVIEW_FAMILY_CODE>> (5 digits). It never expires and can be paired on several devices at the same time.
- Parvoz Parents demo account (iPhone or iPad): phone <<DEMO_PARENT_PHONE>>, password <<DEMO_PARENT_PASSWORD>> (no SMS). Active Premium plan with sample content; nothing to purchase.

HOW TO TEST (iPhone with a passcode, signed in to an Apple Account, online)
1. Choose a language. On the consent screen tap "My parent confirms".
2. Enter the family code; pairing is immediate.
3. Pick an interest. Permissions are optional; please allow Notifications (used by "Ask for more time"), then tap "Continue".
4. Home banner "App restrictions are off" (or Profile tab > gear > Screen Time) > "Turn on protection" > confirm with Face ID or the passcode.
5. "Restricted apps" > "Choose" > create any 4-digit parent PIN > pick apps in Apple's picker > "Done".
6. In Parvoz Parents open the demo child and turn on "Block all apps", or in app restrictions select "iPhone: selected apps" and block it or set a daily limit. With Parvoz Growth open it applies within about a minute (otherwise on next launch or push); the chosen apps then show the Parvoz shield.
7. On the shield tap "Ask for more time", tap the notification, choose minutes, send. Approve in Parvoz Parents: the apps open until the extra time ends, then the shield returns, even if Parvoz Growth is closed.

FAMILY CONTROLS
- Distribution entitlement approved for uz.parvoz.growth and extensions .monitor, .shield, .shieldaction.
- Default: requestAuthorization(for: .individual); a parent confirms with Face ID/passcode on the child's iPhone. Most of our parents use Android phones and cannot create an Apple Family Sharing group. Families using Family Sharing can tap "Strict protection", which requests .child.
- The selection stays on the device (opaque tokens in the App Group). App names, the app list and app usage never leave the iPhone. The server sends only app-agnostic rules (block now, time windows, one daily limit, approved extra time). The app reports only whether access is on and how many apps/categories/sites are selected, shown to the parent as one entry "iPhone: selected apps".
- While protection is on, Date & Time stays Automatic so limits can't be bypassed. If the parent enables "Prevent uninstall", deleting apps is blocked. Optional (parent PIN): adult website filter, block new installs. All end when protection is turned off in Settings > Screen Time.
- Recording of this build: <<VIDEO_URL>>

SOS
Home > chat icon (top right) > "SOS message" > slide "Send SOS". Sends an alert with the current location to the linked parents; it does not contact emergency services.

BACKGROUND MODES
- location: live location for the linked parents and alerts for places they saved. "Always" is optional, asked after "While Using".
- audio: Audiobooks tab > open a book > Play, then lock the iPhone; playback continues with Lock Screen controls.
- remote-notification: parent messages and silent pushes that re-sync the parents' rules.

ACCOUNT DELETION
Profile tab > gear > "Disconnect and delete my data" deletes the child's account and data on our servers and removes the restrictions from this iPhone.

OTHER
- No in-app purchases or payment screens. DON points are virtual, with no cash value or real prizes; Apple is not a sponsor of any quiz or olympiad.
- No ads, tracking or analytics SDK; Firebase Crashlytics only for crash reports.
- Steps use Core Motion, not HealthKit. Camera/microphone only for messages, photos and the pairing QR.
- Designed for iPhone; on iPad step counting is unavailable.
```

**Notes'ni joylashdan oldin tekshiring (yakuniy build'da):**

| Notes'dagi da'vo | Qayerda tekshiriladi |
|---|---|
| Tugma/yozuv nomlari: "My parent confirms", "Turn on protection", "Strict protection", "Choose", "Ask for more time", "SOS message", "Send SOS", "App restrictions are off", "Disconnect and delete my data" | `farzandim_child/assets/translations/en.json` (`consent.confirmButton`, `screenTime.authButton`, `screenTime.strictLink`, `screenTime.appsChoose`, `chats.sosButton`, `chats.sosSlider`, `screenTime.bannerAuthTitle`, `settings.*`), shield matni `ios/ParvozShieldConfig/ParvozShieldConfig.swift` |
| "Disconnect and delete my data" qatori Sozlamalarda bor va ishlaydi (F15) | `settings_screen.dart`; backend `DELETE /users/me` CHILD uchun. Bu qator BO'LMASA — ACCOUNT DELETION bandini olib tashlamang, avval qatorni qo'shing (5.1.1(v)) |
| Demo kod bir nechta qurilmada bir vaqtda ishlaydi | backend `APP_REVIEW_FAMILY_CODES` / `PLAY_REVIEW_FAMILY_CODE` + `pairReviewProfile` (auth.service.ts) PROD'ga deploy qilingan. Deploy bo'lmagan bo'lsa jumlani `It never expires and can be reused on any device (a new pairing signs the previous device out).` ga almashtiring |
| SOS yo'li | Home'da alohida SOS tugmasi qo'shilgan bo'lsa (F33), SOS bandini `Home > SOS button > slide "Send SOS"` ga moslang |
| UIBackgroundModes faqat `location`, `remote-notification`, `audio` | `ios/Runner/Info.plist`. Agar `fetch` hali qolgan bo'lsa (F45) — eng yaxshisi uni olib tashlash; qolsa BACKGROUND MODES'ga qo'shing: `- fetch: required by a background-task plugin; Parvoz Growth performs no periodic background fetch on iOS.` |
| HealthKit ulanmagan | IPA'da `HealthKit.framework` yo'q, Info.plist'da `NSHealth*` yo'q (F5, `third_party/health`) |
| Parvoz Parents'dagi "Block all apps", app restrictions → "iPhone: selected apps", "Extra time" | Do'kondagi JORIY Parvoz Parents versiyasida demo akkaunt bilan qo'lda bosib ko'ring (F25). Nomlar boshqacha bo'lsa 6-7 qadamni moslang |

---

## 2. Age Rating (yangi so'rovnoma, 2025+)

| Savol | Javob | Asos |
|---|---|---|
| Parental Controls | **Yes** | Ekran vaqti cheklovlari, ota-ona PIN'i |
| Age Assurance | **No** | Yosh tekshiruvi yo'q |
| Unrestricted Web Access | **No** | Umumiy brauzer yo'q. Videolar admin tanlagan YouTube ID'lari, `youtube-nocookie.com` embed'ida (`consumer-content.controller.ts`); webview faqat o'z backend'imiz va YouTube embed yo'llariga ruxsat beradi, boshqa navigatsiya bloklangan (`youtube_player_screen.dart`) |
| User-Generated Content | **Yes** (ehtiyotkor javob) | Oila chati (matn/ovoz/video/rasm) va DON reytingida boshqa foydalanuvchilarga bolaning o'zi kiritgan ismi (ism + familiya bosh harfi, rasmsiz) ko'rinadi. Hisoblangan reyting qabul qilinmas bo'lsa, `No` ham himoya qilinadigan javob: oiladan tashqariga faqat filtrlangan ism chiqadi (F16) |
| Messaging and Chat | **Yes** | Faqat bola ↔ o'z ota-onasi; begonalar bilan yozishib bo'lmaydi |
| Advertising | **No** | Reklama SDK yo'q |
| Profanity or Crude Humor / Horror or Fear Themes / Alcohol, Tobacco or Drug Use | **None** | ⚠️ Audiokitob, video va kitob katalogini ko'rib chiqing — ertaklarda qo'rqinchli epizodlar bo'lsa `Infrequent` |
| Medical or Treatment-Focused Content | **None** | |
| Health or Wellness Topics | **Yes** (ehtiyotkor javob) | Kunlik qadam maqsadi va motivatsion maslahatlar ("Good sleep is a source of energy", "Don't forget to drink water" — `en.json` ~289-290). `None` ham himoya qilinadi |
| Mature or Suggestive Themes / Sexual Content or Nudity / Graphic Sexual Content | **None** | |
| Cartoon or Fantasy Violence / Realistic Violence / Prolonged Graphic Violence / Guns or Other Weapons | **None** | ⚠️ Katalogni tekshiring: ertak/multfilmlarda jang sahnalari bo'lsa `Cartoon or Fantasy Violence: Infrequent` |
| Simulated Gambling / Gambling / Loot Boxes | **None / No** | Tasodifiy mukofot, tikish yo'q |
| **Contests** | **Infrequent** (tavsiya) yoki **Frequent** | Ilovada testlar, davriy olimpiadalar, "Contest terms"/"Prize" (DON ballari) va O'zbekiston bo'yicha DON reytingi bor — shuning uchun `None` NOTO'G'RI (F11, Guideline 2.3.6). Olimpiadalar davriy va reyting ikkinchi darajali ekran bo'lgani uchun `Infrequent` himoya qilinadi. Agar musobaqalar doimiy asosiy faoliyat deb hisoblasangiz — `Frequent` (reyting yuqoriroq bo'ladi) |

- Override (yoshni qo'lda oshirish): kerak emas.
- Yakuniy reytingni App Store Connect hisoblaydi — natijani ko'rib chiqing:
  bola qurilmasidagi Apple Account kontent cheklovlari past reytingli
  ilovalarnigina o'rnatishga ruxsat bersa, yuqori reyting o'rnatishni to'sadi.
- Real (pul/buyum) sovrinli tanlov boshlasangiz — avval §8 F43 ni bajaring
  va bu javoblarni qayta ko'rib chiqing.

---

## 3. Category

- Primary: **Lifestyle** (oilaviy xavfsizlik va aloqa).
- Secondary: **Education** (audiokitoblar, videolar, testlar).
- **Kids Category tanlanmaydi**, "Made for Kids" belgilanmaydi. Ilova ota-ona
  nazorati tizimining qismi, auditoriyasi — ota-onalar; metadata ota-ona
  ovozida (F2). Shuning uchun Firebase Crashlytics (uchinchi tomon SDK)
  qoladi, lekin metadata va skrinshotlarda "for kids / for children /
  для детей" bo'lmasligi SHART.

---

## 4. App Privacy (Data Collection) javoblari

"Do you or your third-party partners collect data from this app?" → **Yes**.
Har bir tur uchun: **Used for tracking — No**. Maqsad — faqat **App
Functionality** (Apple ta'rifiga ko'ra bu "minimize app crashes" ni ham
qamraydi, shuning uchun Crashlytics uchun ham shu). **Analytics,
Advertising, Personalization belgilanmaydi** — ilovada analitika va reklama
SDK yo'q (`pubspec.yaml`da `firebase_analytics` yo'q; `GoogleService-Info.plist`
`IS_ANALYTICS_ENABLED=false`, `IS_ADS_ENABLED=false`).

| Apple kategoriyasi | Tur | Linked | Kod manbai / izoh |
|---|---|---|---|
| Location | **Precise Location** | Yes | `location_service.dart` → `POST /location` (lat/lon, aniqlik, tezlik, yo'nalish, balandlik, vaqt); `sos_provider.dart` SOS bilan joylashuv. Geo-zona xabarlari serverda hisoblanadi. Coarse Location alohida belgilanmaydi (Precise uni qamraydi, IP orqali joylashuv aniqlanmaydi) |
| Contact Info | **Name** | Yes | Bola ismi (`child_repository.dart` `PUT /children/me`) |
| Health & Fitness | **Fitness** | Yes | Kunlik qadamlar, Core Motion (`MotionStepsPlugin.swift`). Health (HealthKit) — **No** |
| User Content | **Emails or Text Messages** | Yes | Oila chatidagi matnli xabarlar (ehtiyotkor tanlov; Apple "in-app messages"ni shu yerga kiritadi) |
| User Content | **Photos or Videos** | Yes | Video xabarlar, chatdagi rasmlar, ota-ona so'ragan rasm, profil rasmi |
| User Content | **Audio Data** | Yes | Ovozli xabarlar (va video xabarning ovozi) |
| User Content | **Other User Content** | Yes | Chatdagi fayllar (`file_picker`), test/olimpiada javoblari, qo'shimcha vaqt so'rovining sababi, qiziqishlar |
| Identifiers | **User ID** | Yes | Bola akkaunti ID, Firebase anonim UID (`pairing_provider.dart` `signInAnonymously`) |
| Identifiers | **Device ID** | Yes | Push (FCM/APNs) token, Firebase Installation ID. IDFA ishlatilmaydi |
| Usage Data | **Product Interaction** | Yes | Ko'rilgan videolar/sevimlilar/tarix, audiokitob progressi, o'qilgan kitob/maqolalar, DON va streak (Firestore `xp_service.dart`) — F20 |
| Diagnostics | **Crash Data** | **No** (not linked) | Firebase Crashlytics (`main.dart`), `setUserIdentifier` chaqirilmaydi — F21 |
| Diagnostics | **Other Diagnostic Data** | Yes | Batareya, zaryadlanish, model, iOS va ilova versiyasi, ruxsat holatlari, Ekran vaqti yoqilganmi + tanlangan ilova/toifa/sayt SONI (`device_info_service.dart`, `ios_restrictions_sync_service.dart`) |
| Other Data | **Other Data Types** | Yes | Yosh/tug'ilgan sana, jins, viloyat, qiziqishlar |

**Yig'ilMAYDI (No):** Contact Info (Email, Phone, Physical Address, Other),
Health, Financial Info, Purchases, Contacts, Browsing History, Search
History, Sensitive Info, Advertising Data, **Other Usage Data** (iOS'da
ilovalar ro'yxati va ilovalardan foydalanish statistikasi qurilmadan
chiqmaydi — Family Controls sharti), Gameplay Content (test javoblari Other
User Content'da), Customer Support, Performance Data, Coarse Location.

> **Kod bilan moslik (egasi uchun):** `ios/Runner/PrivacyInfo.xcprivacy`
> hozircha Product Interaction, Emails or Text Messages va Crash Data'ni
> o'z ichiga olmaydi (F20). Privacy manifest yuklashda App Store Connect
> javoblari bilan solishtirilmaydi, shuning uchun bu build'ni to'xtatmaydi —
> lekin keyingi build'da manifestga shu turlarni qo'shing (Runner maqsadi
> bo'yicha alohida vazifa, bu hujjat doirasidan tashqari).

---

## 5. Export Compliance

- `ios/Runner/Info.plist`: `ITSAppUsesNonExemptEncryption = false` →
  App Store Connect shifrlash savolini so'ramaydi.
- Asos: ilova faqat standart, OS/kutubxona taqdim etgan shifrlashdan
  foydalanadi — HTTPS/TLS (Dio, `dart:io`), WSS (socket.io), Firebase SDK'lari
  (TLS), Keychain (`flutter_secure_storage`). O'z shifrlash algoritmi yo'q.
- **WebRTC:** `flutter_webrtc` hali `pubspec.yaml`da va iOS binary'ga ulanadi
  (`WebRTC.framework`), lekin `lib/` ichida uni chaqiradigan Dart kodi YO'Q —
  jonli eshitish faqat Android'da (`ListenService.kt`). iOS'da hech qachon
  DTLS-SRTP sessiya ochilmaydi. Shuning uchun javob o'zgarmaydi. Tavsiya
  (F46): iOS'dan bu plaginni olib tashlash (~10 MB va ReplayKit ulanishi
  yo'qoladi) — alohida vazifa.
- Agar App Store Connect baribir so'rasa: "Does your app use encryption?" →
  Yes; keyingi savolda standart shifrlash bo'yicha istisno variantini
  tanlang (faqat HTTPS/TLS kabi standart protokollar, o'z yoki nostandart
  algoritm yo'q). Hujjat yuklash talab qilinmaydi.

---

## 6. Pricing and Availability

- Price: **Free**. In-App Purchases: **yo'q** (Parvoz Growth'da IAP yoki
  to'lov ekrani yo'q; `pubspec.yaml`da `in_app_purchase` yo'q).
- Countries: egasi tanlaydi (kamida O'zbekiston).
- **Apple Vision Pro** — "Make this app available" belgisini OLIB TASHLANG
  (F57): visionOS'da Family Controls ruxsati doim rad etiladi.
- **Mac (Apple silicon)** — "iPhone and iPad Apps on Apple Silicon Macs"
  belgisini OLIB TASHLANG (F57): Mac'da Screen Time ruxsati ishlamaydi.
- iPad: ilova `UIDeviceFamily = 1` (faqat iPhone), iPad'da moslik rejimida
  ochiladi; Notes'da cheklov aytilgan (qadamlar ishlamaydi).

---

## 7. Version Information

- What's New (birinchi versiyada so'ralmaydi).
- Support URL / Marketing URL / Privacy Policy URL: listing faylining §1.
- Privacy Policy URL ochilganda iOS bo'limi bo'lishi kerak (§8, F10).

---

## 8. EGASI uchun qo'lda bajariladigan ishlar (topshirishdan OLDIN)

### A. Demo (reviewer) muhit — F7, F9, F12, F29, F34

1. **Apple uchun ALOHIDA demo oila** yarating (Google Play demo'sidan
   boshqa): demo ota-ona akkaunti (**telefon + parol** bilan kirish, SMS
   kerak emas — `POST /auth/login` `identifier` + `password`) va unda bitta
   demo bola profili. Ismi neytral (masalan "Demo"), real bola ma'lumoti yo'q.
2. Admin panelda shu ota-onaga **Premium** bering, muddati kamida 120 kun
   (`AdminUsersService.grantSubscription`, `admin-users.service.ts`). Ota-ona
   tokeni bilan `GET /api/me/entitlement` → `tier: premium`, muddati review
   oynasidan keyin. Har qayta topshirishdan oldin qayta tekshiring.
3. Backend `.env` (prod), keyin `pm2 restart`:
   - `APP_REVIEW_FAMILY_CODES=<Apple demo bola kodi>,<Google demo bola kodi>`
     (yangi o'zgaruvchi — backend shu tarmoqdagi o'zgarish bilan deploy
     qilingandan keyin ishlaydi). Deploy qilinmagan bo'lsa — eski
     `PLAY_REVIEW_FAMILY_CODE` faqat BITTA kodni qabul qiladi; review vaqtida
     o'sha kodni boshqa joyda ishlatmang.
   - `PLAY_REVIEW_PARENT_EMAIL=<Apple demo ota-ona telefoni yoki email>` —
     "2 qurilma" limiti reviewer'ni to'smasligi uchun. ⚠️ Bu o'zgaruvchi
     BITTA qiymat oladi: Google Play demo ota-onasi boshqa bo'lsa, ikkala
     do'kon review'i bir vaqtga to'g'ri kelmasin yoki bitta demo ota-onani
     ikkala do'konga bering (bolalar va kodlar alohida).
4. Demo bola kontenti: kamida 1 ta qisqa, **o'ynaydigan audiokitob**
   (background audio testi uchun, F34), bir nechta video va test/olimpiada
   Premium'da ko'rinadigan bo'lsin. Bo'sh ro'yxat yoki soxta kartochka
   ko'rinmasin (F12).
5. Demo bola siyosati: `blockUninstall=false`, `blockAllApps=false`, 0
   daqiqali limit YO'Q (F29) — reviewer o'zi yoqadi.
6. TestFlight iPhone'da sinang: juftlash → ilovani o'chirish → qayta
   o'rnatish → yana juftlash → ikkinchi qurilmada juftlash. Hammasi
   muvaffaqiyatli bo'lsin. Keyin Notes'dagi 1–7 qadamlarni demo ota-ona bilan
   to'liq bosib chiqing (iPad'dagi Parvoz Parents bilan ham).
7. Notes va §1 jadvalidagi `<<...>>` ni to'ldiring; `grep "<<"` bo'sh.
8. **Video** (F4): AYNAN topshiriladigan build'da yozing — Turn on protection
   → Face ID → PIN → picker → ota-ona "Block all apps" → shield → Ask for more
   time → tasdiqlash → ilovalar ochiladi → vaqt tugagach shield qaytadi.
   Havolani `<<VIDEO_URL>>` o'rniga qo'ying (unlisted YouTube yoki Drive).

### B. Backend va ota-ona ilovasi — F24, F25, F26

9. **F24:** `feat/child-ios` backend o'zgarishlarini PR orqali `main`ga
   qo'shing (deploy faqat `main`dan, `.github/workflows/deploy-test.yml`),
   deploy `prisma migrate deploy` ni bajarsin. Tekshiruv: prod
   `GET /api/children/<uuid>/listen-sessions` 404 emas, 401 qaytarsin; fondagi
   TestFlight iPhone'ga `restrictions_sync` push yuborib ko'ring. Deploy'gacha
   Notes "darhol fonda yangilanadi" deb va'da qilmaydi (6-qadam shunday
   yozilgan).
10. **F25:** Parvoz Parents'ning iPhone-bolani qo'llab-quvvatlovchi yangilanishini
    (`a53d85f3` va undan keyingilar) Growth bilan BIRGA yoki undan OLDIN
    chiqaring (App Store va Google Play). Do'kondagi 1.0.1 da rejimlar
    (routines) iPhone ilovalarini kun bo'yi bloklashi mumkin — shuning uchun
    Notes faqat "Block all apps", app restrictions va "Extra time"ni
    ishlatadi. Yangilanish chiqqach Notes'ga jadval (Schedules → "Block
    iPhone apps during this time") qadamini qo'shish mumkin.
11. **F26:** ota-ona ilovasida iPhone bola uchun "Jonli eshitish" kartasini
    yashiring (`child_settings_screen.dart`, `if (!isIos) ...[ ]`), backend
    `listen-sessions` iOS bola uchun aniq xato kodi bilan rad etsin; tarif
    ekrani va Parvoz Parents tavsifida jonli eshitish, ilova statistikasi va
    ilova bo'yicha alohida limitlar "faqat Android" deb belgilansin. iOS
    metadata va Notes'da jonli eshitish TILGA OLINMAYDI.

### C. Sayt va yuridik sahifalar — F10, F20, F21, F43, F44, F52

12. **F10/F20/F21:** `website/public/privacy.html`ga iOS bo'limini qo'shing
    (`docs/PRIVACY_POLICY_IOS_SECTION_DRAFT.md`, UZ + EN + RU), Android'ga xos
    qatorlarni belgilang, Firebase qatorini tuzating, saqlash muddati va
    o'chirish yo'lini haqiqatga moslang, sanani yangilang. Deploy (sayt ildizi
    `website/public` — statik).
13. **F15/F10:** `account-deletion.html`ga Parvoz Growth (iPhone) bo'limini
    qo'shing (o'sha draft'dagi matn).
14. **F52:** `oferta.html` §4 va `tolov-va-qaytarish.html` §1 ga UZ/RU
    qo'shing: "iPhone/iPad'da Parvoz Parents obunasi faqat Apple In-App
    Purchase orqali sotiladi va Apple Account sozlamalarida boshqariladi;
    Click/Uzum/Payme — Android va veb uchun." Ixtiyoriy: bu havolalarni
    privacy.html'ning yuqori menyusidan footer'ga ko'chiring.
15. **F44:** bitta, kuzatiladigan support e-mail tanlang. Ikkala ilova
    (`farzandim_child/.../settings_screen.dart`,
    `Farzandim/.../support_sheet.dart`) `support@farzandimedu.uz`ni
    ko'rsatadi, sayt esa `farzandimtech@gmail.com`ni. Eng arzon yo'l:
    `support@farzandimedu.uz`ga sinov xati yuborib yetib borishini tekshiring
    (yoki gmail'ga forward qiling), keyin saytdagi manzillarni ham shu bilan
    almashtiring. Listing tavsifi `support@farzandimedu.uz`ni ishlatadi; agar
    gmail'ni tanlasangiz — tavsifni ham, ilovalardagi manzilni ham (keyingi
    build) o'zgartiring.
16. **F43:** DON — virtual ball, real sovrin yo'q; Notes'da "Apple is not a
    sponsor" yozilgan. Admin paneldagi "eng ko'p ball to'plagan farzandlar
    sovg'a oladi" push shablonini (`admin-notifications.service.ts`)
    ishlatmang yoki o'chiring. Real sovrinli tanlov o'tkazsangiz: ilova
    ichida rasmiy qoidalar, "Apple bu tanlovning homiysi emas va unda
    ishtirok etmaydi" degan jumla (uz/ru/en) va Age Rating'ni qayta ko'rib
    chiqish SHART (Guideline 5.3).

### D. App Store Connect — F2, F4, F11, F27, F33, F34, F39, F57

17. Listing faylidagi matnlarni EN va RU lokalizatsiyalarga ko'chiring;
    kalit so'zlar baytda ≤100 (F39).
18. §2 Age Rating, §4 App Privacy, §6 Availability (Vision Pro va Mac
    belgisini olib tashlash — F57) javoblarini kiriting.
19. Skrinshotlar: faqat iOS build'dan, "for kids" yozuvlarsiz, real bolalar
    ma'lumotisiz (listing §5).
20. Ixtiyoriy, lekin tavsiya (F6): Family Controls ruxsati berilgan Apple
    yozishmasiga qisqa javob: "The app now defaults to .individual
    authorization (parent confirms with Face ID/passcode on the child's
    iPhone) because most of our parents use Android; .child authorization
    remains available as an optional strict mode."
