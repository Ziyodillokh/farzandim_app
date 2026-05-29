# Parent App UI Audit — 2026-05-12

**Loyiha:** Farzandim (Parent App)
**Auditor:** Claude Code
**Sana:** 2026-05-12
**Holat:** `flutter analyze` → **No issues found** (toza)
**Joriy branch holati:** 28 ta `*_screen.dart`, 21 ta provider, 9 ta repository

---

## XULOSA (qisqacha)

Codebase **asosan production-ga yaqin**, lekin **6 ta aniq mock data manbai**,
**8 ta "tez orada qo'shiladi" SnackBar**, **1 ta TODO comment**, va
**eskirgan ishlatilmaydigan kod** mavjud. Sprint 1 auditda eslatilgan
audiobooks / videos / contests / ranking ekran / analytics ekran / batareya
indikator — **hech biri yo'q** (Sprint 2.4'dagi halol "kerak emas" qarori
to'liq amalga oshirilgan). Asosiy ish: **Dashboard mock data** (rating,
points, screen time, app icons) va **bir nechta UI placeholder SnackBar**
ni hal qilish.

---

## 1. CRITICAL ISSUES (production blocker)

### 1.1 Dashboard — to'liq mock ma'lumot (eng katta muammo)

**Affect:** ilovani ochgan har bir foydalanuvchi 100% mock ma'lumot ko'radi.

#### A) Rating + Points (mock random)
- [lib/features/dashboard/presentation/providers/child_stats_provider.dart:60-96](lib/features/dashboard/presentation/providers/child_stats_provider.dart#L60-L96)
  - `_generateMockStats()`: `rating = 500 + random(500)`, `points = 200 + random(500)`, `screenTime = random(2-8 soat)`, `5-6 ta random ilova`
  - Har bola qo'shilganda avtomatik random qiymatlar
- [lib/features/dashboard/data/models/child_stats.dart:3-44](lib/features/dashboard/data/models/child_stats.dart#L3-L44)
  - Model docstring'da ochiqcha "Mock data"

#### B) "Bugun sarflangan vaqt" karta — mock
- [lib/features/dashboard/presentation/widgets/screen_time_card.dart:42-48](lib/features/dashboard/presentation/widgets/screen_time_card.dart#L42-L48)
  - `formatDuration(stats.screenTime)` — yuqoridagi mock provider'dan keladi

#### C) Ilova ikonchalari (Instagram/YouTube/PUBG/TikTok…) — hardcoded
- [lib/features/dashboard/presentation/providers/child_stats_provider.dart:13-21](lib/features/dashboard/presentation/providers/child_stats_provider.dart#L13-L21)
  - `_mockApps` const list — 7 ta hardcoded ilova
  - Dashboard'da random 5-6 tasi tanlanadi

#### D) "Barcha ilovalarni bloklash" toggle — RAM-only mock
- [lib/features/dashboard/presentation/providers/child_stats_provider.dart:102-109](lib/features/dashboard/presentation/providers/child_stats_provider.dart#L102-L109)
  - `toggleAllAppsBlocked()` faqat lokal `state` o'zgartiradi
  - Comment: "Mock — hozircha faqat UI state. Bosqich 5'da Child App'ga FCM signal yuboriladi"
  - Bola App tomonida hech narsa bo'lmaydi

**Tavsiya:** **REMOVE yoki IMPLEMENT** —
- RatingCard, ScreenTimeCard, "Barcha ilovalarni bloklash" Switch va `+N`
  ilova qatori dashboard'dan **butunlay olib tashlash** (yashirish), yoki
- Child App Firestore'ga real screen time / rating yozadigan qilib
  `child_stats_provider`'ni `app_usage_providers.dart`'dagi Firestore
  stream pattern'iga ko'chirish.

---

### 1.2 Joylashuv tarixi — to'liq mock (8 hardcoded nuqta)

- [lib/features/location/presentation/providers/location_history_provider.dart:12-106](lib/features/location/presentation/providers/location_history_provider.dart#L12-L106)
  - `_generateMockHistory()`: Toshkent ichida 8 ta hardcoded koordinata
    (uy → maktab → uy)
  - "Maktab" va "Uy" geo-zona nomlari hardcoded
- [lib/features/location/presentation/screens/location_history_screen.dart:21-22](lib/features/location/presentation/screens/location_history_screen.dart#L21-L22)
  - Docstring: "Bosqich 4.3: mock data. Range dropdown UI tayyor lekin
    haqiqiy filter Bosqich 5'da..."
- [lib/features/location/presentation/screens/location_history_screen.dart:38](lib/features/location/presentation/screens/location_history_screen.dart#L38)
  - Range dropdown (`24h`/`7d`/`30d`) faqat lokal `setState` — query'ga
    ta'sir qilmaydi (dropdown decorative)

**Tavsiya:** **IMPLEMENT** — `LocationRepository`'da
`streamHistory(childId, range)` qo'shish (Firestore `locations` collection
`childId == X && timestamp >= cutoff` query). Joriy `child_location_provider.dart`
real-time pattern'i model bor.

---

### 1.3 "Hozir nima qilyapsan?" foto so'rovi — to'liq mock

- [lib/features/quick_actions/presentation/providers/photo_requests_provider.dart:11-117](lib/features/quick_actions/presentation/providers/photo_requests_provider.dart)
  - `_buildMockHistory()`: 5 ta hardcoded tarix yozuvi
  - `_mockCaptions`: 5 ta hardcoded matn ("Uydaman, kitob o'qiyapman"...)
  - `sendRequest()` 2 soniyadan keyin `Future.delayed` orqali **avtomatik
    "javob" beradi** random caption bilan — Child App bilan **hech qanday
    haqiqiy aloqa yo'q**
- [lib/features/quick_actions/presentation/screens/photo_request_screen.dart:13-17](lib/features/quick_actions/presentation/screens/photo_request_screen.dart#L13-L17)
  - Docstring: "**Mock**: 5 ta tarix yozuvlari, 'Foto so'rash' 2 soniyadan
    keyin avtomatik javob beradi"
- [lib/features/quick_actions/presentation/screens/photo_request_screen.dart:290](lib/features/quick_actions/presentation/screens/photo_request_screen.dart#L290)
  - "Foto haqiqiy URL'siz — placeholder" (`Icons.image_outlined` placeholder)

**Tavsiya:** **REMOVE** — bu xususiyat Slice MVP'dan tashqari (Child App'da
foto so'rovga javob berish UI yo'q). Dashboard quick-action grid'idan
"Hozir nima qilyapsan?" tile'ini olib tashlash. Yoki uni Stage 2 keyingi
versiyaga qoldirish.

---

### 1.4 ESKIRGAN ishlatilmaydigan mock provider'lar

Loyihada ikkita dublikat feature mavjud — eski `quick_actions/` mock va
yangi Firestore versiyasi. Eski versiya **hech qaerda ishlatilmaydi**,
lekin kodda turibdi:

- [lib/features/quick_actions/presentation/providers/voice_messages_provider.dart:8-110](lib/features/quick_actions/presentation/providers/voice_messages_provider.dart)
  - 8 ta hardcoded mock ovoz xabar
  - **Ishlatilmaydi** — yangi `voice_message/voice_message_providers.dart`
    Firestore stream bilan to'liq almashtirilgan
- [lib/features/quick_actions/data/models/voice_message.dart](lib/features/quick_actions/data/models/voice_message.dart)
  - Eski mock model — hech qaerda import qilinmagan (faqat eski provider'da)
- [lib/features/quick_actions/presentation/providers/app_restrictions_provider.dart:1-119](lib/features/quick_actions/presentation/providers/app_restrictions_provider.dart)
  - 8 ta hardcoded ilova (Instagram, YouTube, TikTok, PUBG, Telegram,
    Pinterest, Chrome, WhatsApp)
  - **Ishlatilmaydi** — yangi `app_restrictions/app_usage_providers.dart`
    Firestore stream bilan to'liq almashtirilgan
- [lib/features/quick_actions/data/models/app_restriction.dart](lib/features/quick_actions/data/models/app_restriction.dart)
  - Eski mock model

**Tavsiya:** **REMOVE** — quyidagilar o'chirilsin:
- `lib/features/quick_actions/presentation/providers/voice_messages_provider.dart`
- `lib/features/quick_actions/presentation/providers/app_restrictions_provider.dart`
- `lib/features/quick_actions/data/models/voice_message.dart`
- `lib/features/quick_actions/data/models/app_restriction.dart`

Tekshirish: grep'da `voiceMessagesProvider`/`appRestrictionsProvider` faqat
shu fayllarning ichida — boshqa joyda foydalanilmaydi.

---

## 2. UI/UX ISSUES — "tez orada qo'shiladi" SnackBar'lar

8 ta UI joyda foydalanuvchi tugma bosadi va "tez orada qo'shiladi"
SnackBar ko'radi (dead-end). Bu **production'da uchratish mumkin emas**
ko'rsatkich.

| # | Joy | Matn |
|---|---|------|
| 1 | [bottom_dashboard_bar.dart:29](lib/features/dashboard/presentation/widgets/bottom_dashboard_bar.dart#L29) | Dashboard pastidagi "Foydalanish vaqti" lime green tugma → "Bu xususiyat tez orada qo'shiladi" |
| 2 | [rating_card.dart:44](lib/features/dashboard/presentation/widgets/rating_card.dart#L44) | RatingCard sarlavhasidagi "Batafsil >" link → "Reyting tarixi tez orada qo'shiladi" |
| 3 | [location_map_screen.dart:231](lib/features/location/presentation/screens/location_map_screen.dart#L231) | Xarita yuqorisidagi bola tanlash pill → "Bola tanlash tez orada qo'shiladi" |
| 4 | [voice_chat_screen.dart:118](lib/features/voice_message/presentation/screens/voice_chat_screen.dart#L118) | Ovoz chat ekrani info tugmasi → "Bola sozlamalari tez orada" |
| 5 | [family_code_screen.dart:652](lib/features/child_management/presentation/screens/family_code_screen.dart#L652) | "Texnik yordam olish" link → "Texnik yordam: +998 XX XXX-XX-XX (tez orada qo'shiladi)" |
| 6 | [family_code_screen.dart:696](lib/features/child_management/presentation/screens/family_code_screen.dart#L696) | "Farzandni taklif qilish" share matnida "[Play Store / App Store linklari tez orada qo'shiladi]" |
| 7 | [sign_in_screen.dart:79](lib/features/auth/presentation/screens/sign_in_screen.dart#L79) | Sign In ekranidagi "Hisob qo'shish" tugma → 1.5s spinner + "Bu funksiya tez orada qo'shiladi" (false-loading anti-pattern) |
| 8 | [about_screen.dart:113](lib/features/settings/presentation/screens/about_screen.dart#L113) | About ekranidagi "Foydalanuvchi shartnomasi" va "Maxfiylik siyosati" linklari → "Tez orada qo'shiladi" |

### Boshqa UX kamchilik

- [settings_screen.dart:225](lib/features/settings/presentation/screens/settings_screen.dart#L225)
  — Til tanlash dialog'i tildan keyin "Til o'zgartirildi (haqiqiy tarjima keyin)"
  SnackBar ko'rsatadi. **Lokalizatsiya yo'q** — tanlangan til UI'ga ta'sir qilmaydi.
- [settings_screen.dart:297](lib/features/settings/presentation/screens/settings_screen.dart#L297)
  — Comment: `// ─── Logout (mock) ───` — lekin logout aslida real
  (Firebase signOut + FCM token o'chirish). Comment yolg'on, **olib tashlash kerak**.
- [child_stats_provider.dart:124-136](lib/features/dashboard/presentation/providers/child_stats_provider.dart#L124-L136)
  — `_MockApp` private class hali ham mock_app deb nomlanmoqda.

---

## 3. PROVIDER / BACKEND HOLATI

### 3.1 Firestore'ga to'liq ulangan (production-ready) — 11 ta

| Provider | Type | Status |
|---|---|---|
| `auth_provider.dart` | StateNotifier + Firebase Auth | OK |
| `children_provider.dart` | StreamProvider (Firestore) | OK |
| `profile_provider.dart` | StateNotifier + Firestore | OK |
| `location/child_location_provider.dart` | StreamProvider (Firestore) | OK |
| `geo_zones_provider.dart` | StreamProvider (Firestore) | OK |
| `geo_zone_event_providers.dart` | StreamProvider (Firestore) | OK |
| `notifications_provider.dart` | StreamProvider (Firestore) | OK |
| `fcm_provider.dart` | Service wrapper | OK |
| `schedule_providers.dart` | StreamProvider (Firestore) | OK |
| `app_restrictions/app_usage_providers.dart` | StreamProvider x4 (Firestore) | OK |
| `voice_message_providers.dart` | StreamProvider (Firestore + Storage) | OK |
| `audio_player_provider.dart` | StateNotifier (audio kontrol) | OK |
| `voice_upload_provider.dart` | StateNotifier (Storage upload) | OK |

### 3.2 Lokal/UI state (ma'qul — backend kerak emas)
- `selected_child_index_provider.dart` — `StateProvider<int>` (faqat UI)
- `language_provider.dart` — `StateProvider<AppLanguage>` (haqiqatda
  tarjima sinflari yo'q — pastga qarang)
- `notification_settings_provider.dart` — RAM-only `StateNotifier`
  (toggle'lar Firestore'ga yozilmaydi — pastga qarang)

### 3.3 Mock/RAM-only (production blocker) — 4 ta

| Provider | Issue | Recommendation |
|---|---|---|
| `dashboard/child_stats_provider.dart` | Random rating/points/screenTime, 7 hardcoded ilova | REMOVE (UI'dan rating va screen-time karta olib tashlash) |
| `location/location_history_provider.dart` | 8 hardcoded LatLng | IMPLEMENT (Firestore stream) |
| `quick_actions/photo_requests_provider.dart` | 5 mock + 2s fake response | REMOVE (xususiyat hozircha kerak emas) |
| `quick_actions/voice_messages_provider.dart` | 8 mock xabar | DELETE (ishlatilmagan eskirgan kod) |
| `quick_actions/app_restrictions_provider.dart` | 8 hardcoded ilova | DELETE (ishlatilmagan eskirgan kod) |

### 3.4 Yarim implementatsiya

- **`notification_settings_provider.dart`** — `pushEnabled`/`locationAlerts`/
  `geoZoneAlerts` toggle'lari (Settings ekranida ko'rinadi) **faqat lokal
  state**. Foydalanuvchi qayta kirsa default qaytadi.
  - **Tavsiya:** Firestore'dagi `users/{uid}` document'iga
    `notificationSettings` map qilish; toggle'larni shu yerga yozish.
- **`language_provider.dart`** — `selectedLanguageProvider` til'ni saqlaydi,
  lekin `easy_localization` paketi `pubspec.yaml`'da yo'q va `.tr()`
  chaqiruvlar kodda yo'q. UI'da hech narsa tarjima qilinmaydi.
  - **Tavsiya:** TIL — bu MVP doirasidan tashqari. Settings'dagi "Til"
    qatorini **olib tashlash** (yoki shartlangan tarjima paketini qo'shib,
    `uz`/`ru`/`en` JSON fayllarni to'ldirish — 4-8 soat ish).

---

## 4. SCREEN-BY-SCREEN AUDIT

| # | Screen | Holat | Mock? | Tegishli muammo |
|---|---|---|---|---|
| 1 | `welcome_screen` | OK | — | — |
| 2 | `sign_up_screen` | OK | — | — |
| 3 | `sign_in_screen` | UI dead-end | — | 2.7 ("Hisob qo'shish" tugma) |
| 4 | `forgot_password_screen` | OK | — | — |
| 5 | `verify_otp_screen` | OK | — | — |
| 6 | `dashboard_screen` (`child_management/`) | **MOCK** | YES | 1.1, 2.1, 2.2 |
| 7 | `add_child_screen` | OK | — | — |
| 8 | `children_management_screen` | OK | — | — |
| 9 | `family_code_screen` | UI dead-end | — | 2.5, 2.6 |
| 10 | `profile_screen` | OK | — | — |
| 11 | `location_map_screen` | UI dead-end | — | 2.3 + line 290 TODO |
| 12 | `location_history_screen` | **MOCK** | YES | 1.2 (Range dropdown UI tayyor, query yo'q) |
| 13 | `geo_zones_list_screen` | OK | — | — |
| 14 | `add_edit_geo_zone_screen` | OK | — | — |
| 15 | `full_screen_map_screen` | OK | — | — |
| 16 | `geo_zone_events_screen` | OK | — | — |
| 17 | `notifications_screen` | OK | — | — |
| 18 | `app_restrictions_screen` (`app_restrictions/`) | OK (Firestore) | — | — |
| 19 | `schedules_list_screen` | OK | — | — |
| 20 | `voice_messages_screen` (`quick_actions/`) | OK | — | — |
| 21 | `voice_chat_screen` (`voice_message/`) | UI dead-end | — | 2.4 (info button) |
| 22 | `photo_request_screen` (`quick_actions/`) | **MOCK** | YES | 1.3 |
| 23 | `device_settings_screen` (`quick_actions/`) | OK (Firestore) | — | — |
| 24 | `settings_screen` | Yarim | — | 3.4 (toggles ephemeral), 2 ta yolg'on SnackBar |
| 25 | `about_screen` | UI dead-end | — | 2.8 (legal linklar broken) |
| 26 | `delete_account_screen` | OK | — | — |
| 27 | `privacy_policy_screen` | OK | — | — |
| 28 | `terms_of_service_screen` | OK | — | — |

### Routing
- 23 ta route to'g'ri ulangan (auth-protected redirect bor)
- [app_router.dart:294-317](lib/core/routing/app_router.dart#L294-L317) — `_ComingSoonScreen` private class.
  - Faqat 1 joyda fallback sifatida ishlatiladi (verify_otp route'iga direkt
    URL ochilsa). Real production'da uchramaydi — **qoldirish mumkin**,
    yoki Welcome'ga redirect qilish.

---

## 5. SPRINT 1 AUDITDA ESLATILGAN FEATURES — joriy holat

| Feature | Joriy holat |
|---|---|
| **Audiobooks** | Yo'q — `find lib -iname "*audiobook*"` natijasi bo'sh |
| **Videos** | Yo'q — `find lib -iname "*video*"` natijasi bo'sh |
| **Contests** | Yo'q — `find lib -iname "*contest*"` natijasi bo'sh |
| **Ranking** (alohida ekran) | Yo'q — faqat `RatingCard` dashboard'da mock |
| **Analytics** (alohida ekran) | Yo'q — Firebase Analytics observer bor (`app_router.dart:84`), screen_view event'lar yuboriladi |
| **Battery indicator** (xaritada) | UI'da yo'q — model'da `batteryLevel` bor (`child_device_info.dart`), `device_settings_screen.dart:267` da ko'rinadi (real), lekin xaritada yo'q. Bunga TODO bor: [location_map_screen.dart:290-291](lib/features/location/presentation/screens/location_map_screen.dart#L290-L291) |

**Xulosa:** Audiobooks/videos/contests/ranking/analytics — **butunlay
olib tashlangan** (Sprint 2.4 qaror amalga oshirilgan). Faqat Dashboard'da
"Reyting" so'zi qolib ketgan — mock raqam bilan.

---

## 6. SHOSHILMASLIK USTUVORLIGI (tavsiyalar)

### 6.A) REMOVE (UI'dan yashirin — eng tez yutuq) — **~2-3 soat**

Quyidagi UI elementlar production'ga tayyor emas, lekin **funktsional alter-
nativa yo'q**. UI'dan butunlay olib tashlash kerak:

1. **Dashboard RatingCard** (`dashboard_screen.dart:142-145`) — mock rating
   raqami va "Batafsil > Reyting tarixi" link.
2. **Dashboard ScreenTimeCard** (`dashboard_screen.dart:147-149`) — mock
   "Bugun sarflangan vaqt", overlap ikonalar va "Barcha ilovalarni
   bloklash" toggle. **Eslatma:** real screen time `app_restrictions_screen`'da
   bor (Firestore), shu yerga link bering.
3. **Dashboard "Foydalanish vaqti" tugma** (`bottom_dashboard_bar.dart:19-35`)
   — `app_restrictions_screen`'ga ulash, yoki olib tashlash.
4. **Quick Action: "Hozir nima qilyapsan?"** (`dashboard_screen.dart:289-294`)
   — fully mock, Child App tomonida implementatsiya yo'q. Olib tashlash.
5. **Sign In: "Hisob qo'shish" tugma** (`sign_in_screen.dart:73-81`)
   — multi-account funktsiya yo'q. Olib tashlash.
6. **About screen: 2 ta "tez orada" link** (`about_screen.dart:83-91`)
   — Settings'da to'g'ri linklar bor, About'dagi dublikatlarni `legal*`
   route'ga ulash yoki olib tashlash.
7. **Settings: Til qatori** (`settings_screen.dart:107-117`) — lokalizatsiya
   yo'q. Olib tashlash yoki `pubspec` ga `easy_localization` qo'shish.
8. **Family code: "Texnik yordam olish" link** (`family_code_screen.dart:642-668`)
   — Settings'dagi haqiqiy "Texnik yordam" dialog'iga ulash.
9. **Family code: share matnidagi "[Play Store / App Store ... tez orada]"**
   (`family_code_screen.dart:696`) — yo'q, faqat oila kodini yuboring.
10. **Location map: "Bola tanlash" pill** (`location_map_screen.dart:226-235`)
    — bola tanlash bottom sheet implement qilish (oson — `childrenProvider`
    mavjud), yoki agar bitta bola bo'lsa pill'ni `static` ko'rsatish.
11. **Voice chat: info tugmasi** (`voice_chat_screen.dart:115-122`)
    — `device_settings_screen`'ga ulash yoki ikonkani olib tashlash.

**Files to delete** (ishlatilmaydigan eski mock kod):
- `lib/features/quick_actions/presentation/providers/voice_messages_provider.dart`
- `lib/features/quick_actions/presentation/providers/app_restrictions_provider.dart`
- `lib/features/quick_actions/data/models/voice_message.dart`
- `lib/features/quick_actions/data/models/app_restriction.dart`

---

### 6.B) IMPLEMENT (real backend bilan ulash) — **~12-18 soat**

1. **Location history** (3-5 soat)
   - `LocationRepository.streamHistory(childId, Duration range)`
   - `location_history_provider.dart`'ni `StreamProvider.family` qilib
     qayta yozish
   - Range dropdown'ni provider'ga ulash
2. **Notification settings persist** (1-2 soat)
   - `users/{uid}.notificationSettings` Firestore map
   - `notification_settings_provider.dart` Firestore read/write
3. **Bola tanlash bottom sheet** (1 soat)
   - Location map'da `_BottomSheet` bilan `childrenProvider` ro'yxati
4. **Map'da batareya indikator** (30 daq) —
   `location_map_screen.dart:290` TODO. `child.deviceInfo.batteryLevel`
   bottom card'ga qo'shish.
5. **Til/lokalizatsiya** (agar kerak bo'lsa) (6-10 soat)
   - `easy_localization` paket
   - `uz.json`/`ru.json`/`en.json` (CLAUDE.md'da rejada bor)
   - Bu MVP'dan tashqari — **suspending recommendation**

---

### 6.C) POLISH (kichik tweaks) — **~1 soat**

1. `settings_screen.dart:297` — `// ─── Logout (mock) ───` comment'ni
   `// ─── Logout ───` ga o'zgartirish (logout real).
2. `app_router.dart:294-317` `_ComingSoonScreen` — Welcome'ga `context.go`
   qilib, ekran o'rniga redirect (1 ta foydalanuvchi ko'rmaydigan edge case).
3. `location_map_screen.dart:290-291` TODO comment — implement bo'lgandan
   keyin olib tashlash.

---

## 7. ESTIMATED EFFORT (jami)

| Toifa | Soat |
|---|---|
| **A) REMOVE** (UI cleanup + 4 fayl o'chirish) | **2-3** |
| **B) IMPLEMENT** (location history + notification settings + bola tanlash + batareya) | **6-9** |
| **C) POLISH** (3 ta kichik tweak) | **~1** |
| **YIG'INDISI (til'siz)** | **9-13** |
| Optional: Lokalizatsiya | +6-10 |

**Eng tez tegib production-ready holat:** A) + bola tanlash + batareya =
**3-4 soat**. Bu yerda Dashboard'dan rating/screen-time karta olinadi,
8 ta dead-end SnackBar yo'qoladi, eski mock fayllar o'chiriladi.

---

## 8. VERIFICATION CHECKLIST

Audit asosida o'zgartirishlar kiritilgandan keyin:

```bash
flutter analyze                                           # toza qolishi kerak
grep -rn "tez orada\|coming soon\|Mock\|mock" lib/ \
  --include="*.dart" | grep -v "data/models" | grep -v "_test.dart"
# → bo'sh natija (yoki faqat data/model docstring'lar)
grep -rn "Foto haqiqiy URL'siz\|hozir ishlamayapti" lib/ --include="*.dart"
# → bo'sh
grep -rn "_generateMockHistory\|_buildMockChat\|_generateMockStats\|_buildMockHistory" \
  lib/ --include="*.dart"
# → bo'sh (yoki faqat o'chirilishi kerak bo'lgan fayllarda)
```

---

## ILOVA: Sprint 1 audit muvaffaqiyati

Sprint 1 audit (Mac sessiya) audiobooks / videos / contests / ranking / analytics /
battery feature'larini mock deb belgilagan edi. **Sprint 2.4** ularni
"kerak emas" deb halol olib tashlagan. Joriy `find` natijalari tasdiqlaydi:
ushbu feature'larga aloqador hech qanday fayl qolmagan. Yagona qoldiq —
**Dashboard'dagi mock RatingCard** ("Reyting" so'zi yodgorlik sifatida),
buni ham ushbu audit `REMOVE` ro'yxatiga kiritdi.
