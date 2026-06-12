# PARENT APP TO'LIQ AUDIT — 2026-06-12

> 58 agent, 8 yo'nalish, har topilma alohida skeptik agent tomonidan kod bilan qayta tasdiqlangan.
> Qamrov: `Farzandim/` (194 fayl, 43K qator, 23 feature). Maqsad: 10k → 100k → 1M user.
> **48 tasdiqlangan topilma** (9 blocker-darajali, dedupdan keyin 5 ta P0 ildiz) + 27 minor.
> Bu hujjat KEYINGI SESSIYALARDA tuzatish rejasi sifatida ishlatiladi — band tugagach [x] belgilang.

## UMUMIY BAHO

Kod tartibli yozilgan (widgetlar bo'laklangan, dispose'lar asosan to'g'ri, render qatlami toza —
GlassCard blur'siz, animatsiyalar to'g'ri boshqariladi). Asosiy xavf UI'da emas, **data qatlamida**:
polling arxitekturasi masshtabga chidamaydi, repository'lar xatoni yutadi, kesh qatlami umuman yo'q.
100k user uchun hozirgi holatda backend ~5-10k RPS keraksiz yuk oladi va foydalanuvchilar batareya
shikoyat qiladi. Quyidagi P0'lar tuzatilsa — arxitektura 100k'ga bemalol chidaydi.

---

## P0 — DARHOL (masshtab blockerlari + xavfli buglar)

### [x] P0-1. Polling provayderlar ABADIY ishlaydi (eng katta tizimli muammo) — effort: M/L
8 yo'nalishdan 6 tasi mustaqil topdi (PERF-01, NET-01/02, ARCH-01, BUG-01, ST-01, MEM-1, SCR-01).
- **Fayllar:**
  - `lib/features/app_restrictions/presentation/providers/app_usage_providers.dart:21-60` — todayUsage (30s), installedApps (60s)
  - `lib/features/dashboard/presentation/widgets/screen_time_chart.dart:20-44` — weeklyChildUsage (30s)
  - `lib/features/child_management/presentation/providers/children_provider.dart:33-40` — statusTick (30s/60s → /children refetch)
- **Muammo:** Birorta polling provider `.autoDispose` emas (butun lib'da atigi 1 ta haqiqiy autoDispose bor).
  Ekran bir marta ochilgach polling ILOVA UMRI DAVOMIDA davom etadi — boshqa ekranda ham, ilova
  FONDA turganda ham. Har ko'rilgan bola uchun ~5 req/min to'planib boradi.
- **Masshtab matematikasi:** 1 user ≈ 0.08-0.15 RPS doimiy; 100k user (20-30% jonli protsess) =
  **2-5k RPS faqat keraksiz pollingdan** + telefon batareyasi shikoyatlari.
- **Fix:**
  1. Barcha polling provayderlarga `.autoDispose` (kerak bo'lsa `ref.keepAlive()` + 1-2 daqiqa kesh).
  2. Global `appLifecycleProvider` — `AppLifecycleState.paused`da barcha polling to'xtaydi.
  3. Poll natijasi o'zgarmagan bo'lsa yield qilmaslik (Child'da to'g'ri `==` bor — listEquals dedup) —
     60 soniyalik butun-ekran rebuild'lar yo'qoladi.
  4. Uzoq muddat: usage/status uchun WS push (socket allaqachon bor) — pollingni butunlay olib tashlash.

### [x] P0-2. PARENT'da ham refresh-token "har xatoda clear" bug'i — effort: S
(EH-01 + NET-04 + BUG-03 + EH-02) — child'da tuzatganimizning aynan o'zi parent'da ham bor!
- **Fayl:** `lib/core/network/dio_client.dart:186-193`
- **Muammo:** Refresh chaqiruvi timeout/5xx/tarmoq xatosida ham `tokenStorage.clear()` qiladi —
  backend deploy oynasida **ommaviy jim logout** (100k user'da minglab foydalanuvchi birdan chiqib ketadi).
- **Qo'shimcha (EH-02):** clear bo'lgach auth state XABARDOR QILINMAYDI — foydalanuvchi "zombi"
  holatda qoladi (ekranlar ochiq, hamma so'rov 401, login'ga redirect yo'q, xabar yo'q).
- **Fix:** child'dagi kabi faqat aniq 401/403'da clear + clear bo'lganda `backendAuthProvider`ni
  logout holatiga o'tkazish (router login'ga olib boradi, "Sessiya tugadi" xabari).

### [x] P0-3. SOS xatosi yutiladi — favqulodda holatda yolg'on "Hammasi tinch" — effort: S
(EH-03)
- **Fayl:** `lib/features/sos/data/repositories/backend_sos_repository.dart:52-55` + sos_alerts_screen
- **Muammo:** `getAlerts` xatoda `[]` qaytaradi → ota-ona favqulodda vaziyatda offline bo'lsa
  ekranda "SOS signallari yo'q — hammasi tinch" ko'radi. Bu xavfsizlik ilovasida eng yomon yolg'on.
- **Fix:** Repository xatoni throw qilsin; ekranda aniq xato holati + retry tugmasi.

### [x] P0-4. Voice/video xabarlar: pagination yo'q + har 60s TO'LIQ tarix qayta yuklanadi — effort: M
(ARCH-02 + BUG-10 + NET-03)
- **Fayllar:** `lib/features/voice_message/presentation/providers/voice_message_providers.dart:48-83`,
  `backend_voice_message_repository.dart:49-58`
- **Muammo:** voiceMessagesProvider `childrenListProvider`ni watch qiladi → har 60s children tick'ida
  yangi List identity → BUTUN xabar tarixi (limit'siz!) qayta fetch. Faol oila 1 yilda minglab xabar
  yig'adi — har 60s shularning hammasi qayta yuklanadi.
- **Fix:** (1) `childrenListProvider` o'rniga faqat kerakli childId'larni `select` bilan olish,
  (2) backend'dan limit/cursor pagination so'rash, (3) yangi xabarlar WS orqali qo'shilsin (socket bor).

### [x] P0-5. UTC vaqtlar .toLocal()'siz — joylashuv tarixi 5 soat noto'g'ri — effort: S
(BUG-04)
- **Fayllar:** `lib/features/location/data/models/child_location.dart:46`,
  `lib/features/location/data/models/geo_zone_event.dart:78`
- **Muammo:** Backend UTC ("Z") qaytaradi, UI .toLocal()'siz ko'rsatadi — Toshkentda (UTC+5)
  barcha tarix vaqtlari 5 soat orqada ko'rinadi.
- **Fix:** Parse joyida `.toLocal()` yoki ko'rsatish formatterlarida.

---

## P1 — MUHIM (keyingi navbat)

### Xato handling / UX
- [x] **EH-04** (S): Limit/blok O'CHIRISH offline'da yolg'on "saqlandi" qaytaradi (blok aslida qoladi) —
  `backend_app_limit_repository.dart:39-54,93-107` — xatoni throw + UI feedback.
- [x] **EH-09** (M): Umumiy pattern — usage/installed-apps/permissions/pair-requests repolari xatoni
  yutib bo'sh/0/"hammasi ruxsat" qaytaradi. Repository qatlamini throw'ga o'tkazish + ekranlarda error holat.
- [x] **EH-05** (S): Dashboard birinchi yuklanish xatosida abadiy spinner (offline'da xabar/retry yo'q) —
  `dashboard_screen.dart:55-64`.
- [x] **EH-07** (S): Ilova-ruxsat toggle xatoda jim yiqiladi (unawaited, catch yo'q) —
  `permission_apps_screen.dart:50-62,159`.
- [x] **EH-06** (S): Repair-QR dialog avto-yopilmaydi — hujjatdagi `child:repaired` WS listener
  implementatsiya qilinmagan — `repair_qr_dialog.dart:15-17,64-132`.
- [x] **EH-08** (S, minor): Child CRUD xatolarida xom inglizcha `e.toString()` ko'rsatiladi — o'zbekcha xabar.

### Startup (ochilish tezligi)
- [x] **ST-02** (S): `main.dart:81-148` — 8 ta ketma-ket await; parallellashtirilsa cold start sezilarli tezlashadi
  (ApiKeys+EasyLocalization+displayMode parallel; Crashlytics/Analytics/AppCheck birinchi frame'dan keyinga).
- [x] **ST-03** (M): Login bo'lgan userga har cold start'da Welcome ekran "flash" + 325KB jpg dekod —
  splash/redirect route kerak — `app_router.dart:164,179`.
- [x] **ST-04** (S): GoogleFonts Inter runtime'da internetdan yuklanadi — shriftni assets'ga bundle qilish
  (birinchi o'rnatishda sekin tarmoqda matn kechikadi).
- [ ] **ST-05** (M): Dashboard ikki ketma-ket to'lqin (/children tugamaguncha profil/usage boshlanmaydi) —
  `dashboard_screen.dart:47-64,793,958-968`.
- [x] **ST-06** (S, minor): FCM token cold start'da 2 marta POST; anonim holatda kafolatlangan 401 so'rov.
- [x] **ST-07** (S, minor): Har so'rovda access token secure-storage'dan qayta o'qiladi — memory kesh.

### Performance (UI)
- [ ] **PERF-03 + SCR-03** (M): AppLimits ro'yxati builder'siz (hamma qator birdan) + har 30s poll'da
  sort/merge qayta — `app_limits_screen.dart:95-106,255-285` — ListView.builder + memoize.
- [x] **PERF-04 + MEM-7** (S): AppIconWidget har rebuild'da base64Decode → yangi Uint8List → image kesh
  har safar sog'inadi — `app_icon_widget.dart:90-109` — bytes'ni memoize (initState/cache).
- [x] **PERF-05** (M): Voice chat yozish paytida amplitude 10Hz BUTUN ekranni rebuild qiladi —
  `voice_chat_screen.dart:188-207` — amplitude'ni faqat indikator widget'iga izolyatsiya qilish.
- [x] **PERF-06 + SCR-04** (M): LocationHistory har rebuild'da haversine×2 + dwell-detection qayta —
  `location_history_screen.dart:148-150,235,456-466` — hisoblarni data o'zgarganda bir marta (memoize).
- [x] **PERF-07 + NET-05 + ARCH-03** (S): DeviceSettings har 10s `ref.invalidate(childrenProvider)` —
  ilova bo'ylab hamma watcher'ni qayta fetch'ga majburlaydi — tick-pattern'ga o'tkazish (60s yetarli).
- [x] **SCR-05** (S): Xarita avatar-marker builder'da in-flight guard yo'q — parallel network fetch +
  canvas render har build'da — `location_map_screen.dart:59-72,131-133`.
- [x] **SCR-02** (S): Xaritada auto-follow birinchi programmatik kameradan keyin o'zini o'chiradi
  (onCameraMoveStarted programmatik harakatni user harakati deb biladi) — `location_map_screen.dart:88-107`.

### Xotira
- [ ] **MEM-3** (M): RoundVideoBubble — har bubble thumbnail uchun JONLI VideoPlayerController (ExoPlayer)
  ochadi — uzun chatda o'nlab native player — `round_video_bubble.dart:68-70` — thumbnail PNG yaratish/kesh.
- [x] **MEM-4 + NET-06 + ARCH-11** (M): Disk rasm-keshi umuman yo'q — barcha avatar/ikonka har cold-start'da
  qayta yuklanadi + to'liq o'lchamda dekod — `cached_network_image` + `cacheWidth` hammasiga.
- [ ] **MEM-5** (S, minor): Support chat biriktirma bytes'lari (MB'lab) state'da abadiy qoladi.
- [ ] **MEM-6** (S, minor): Marker bitmap static keshlar cheksiz o'sadi — cap qo'yish.

### Tarmoq / Arxitektura
- [ ] **NET-07** (L): Stale-while-revalidate kesh qatlami yo'q — har ekran ochilish og'ir endpointlarni
  qayta uradi. Yagona yengil kesh qatlami (memory + vaqt) — backend yukini 30-50% kamaytiradi.
- [ ] **NET-10** (S, minor): Retry/backoff yo'q — backend tiklanayotganda hamma klient bir vaqtda uradi
  (thundering herd) — jitter'li backoff.
- [x] **ARCH-05** (S): UI'da to'g'ridan-to'g'ri Dio (repair QR POST, xom Dio().download) — repository'ga ko'chirish.
- [x] **ARCH-06** (S): ~740 qator o'lik kod — 7 ta hech qayerdan import qilinmaydigan fayl (child_page_view.dart
  va b.) — o'chirish.
- [x] **ARCH-07** (M): Vaqt formatlash 6+ joyda hardcoded dublikat — markaziy formatter'ga yig'ish.
- [x] **ARCH-10** (S): Force-update dialog rebuild'da qayta-qayta ochiladi — dedup guard — `app.dart:185-195`.
- [x] **BUG-02** (S): FCM push tap `router.go()` — stack bo'shab "orqaga" GoError — `fcm_service.dart:230-270` —
  `push` yoki to'g'ri stack qurish.

---

## P2 — YAXSHILASH (vaqt bo'lganda)

- [ ] **ARCH-12**: fromJson'larda qattiq `as int` cast'lar — bitta buzuq element ro'yxatni yiqitadi (defensive parse).
- [ ] **ARCH-13**: 1000+ qatorli monolit ekranlar bo'lish (dashboard 1252, location_map 1181, history 994).
- [ ] **ARCH-14**: 43K qator uchun jami 1 ta test — kamida critical-path testlar (auth, status hisoblash, parse).
- [ ] **ARCH-08**: Toshkent UTC+5 hack 4 joyda dublikat — bitta util.
- [ ] **BUG-05**: blockAllApps toggle race — eskirgan 60s refetch optimistik holatni qaytaradi.
- [ ] **BUG-07**: `voiceChat.cameraPermissionSnack` tarjima kaliti 3 tilda ham yo'q (xom kalit ko'rinadi).
- [ ] **BUG-08**: todayScreenTime topilmasa weekly.last (boshqa kun!) ko'rsatiladi.
- [ ] **BUG-09**: NotificationsNotifier._load() poygasi — load tugashidan oldin kelgan FCM yo'qolishi mumkin.
- [ ] **ST-08**: Notification ruxsat dialogi til tanlash ustida chiqadi — onboarding'dan keyinga.
- [ ] **SCR-07/08**: Support chat rasm cacheWidth + scroll jumpTo aniqligi.
- [ ] **SCR-09**: _placeAddressProvider/locationHistoryProvider family keshlari cheksiz o'sadi.
- [ ] **PERF-09/10**: VoiceChatBubble shartsiz watch; auto-scroll har rebuild'da.
- [ ] **MEM-9**: watchLocation har WS event'da to'liq payload debugPrint (release'da ham).
- [ ] **NET-08**: geo-zone-events limit'siz so'rov.
- [ ] **EH-10**: SOS pull-to-refresh bo'sh holatda yo'q.
- [ ] **SCR-10**: O'lik kod qoldiqlari (_recenterDebounce, viewInsets*0).

---

## TAVSIYA ETILGAN TUZATISH TARTIBI (sessiyalar bo'yicha)

| Sessiya | Bandlar | Natija |
|---|---|---|
| 1 | P0-1 (autoDispose+lifecycle+dedup) + P0-2 (refresh clear+zombi) | Backend yuki ~80% kamayadi, ommaviy logout yo'qoladi |
| 2 | P0-3 (SOS) + P0-5 (UTC) + EH-04/05/07/09 (xato handling to'lqini) | Yolg'on holatlar yo'qoladi, offline halol |
| 3 | P0-4 (voice pagination) + NET-07 (kesh qatlami) + NET-10 (backoff) | Tarmoq qatlami masshtabga tayyor |
| 4 | ST-02/03/04/05 (startup to'lqini) | Cold start sezilarli tez |
| 5 | PERF-03/04/05/06/07 + SCR-02/05 + MEM-3/4 | UI silliq, xotira barqaror |
| 6 | ARCH-05/06/07/10 + BUG-02 + P2 tanlab | Clean code |

**Eslatma:** P0-2 child ilovada allaqachon tuzatilgan (bc61199) — parent'dagi kod deyarli bir xil,
o'sha patch'ni moslashtirish kifoya.
