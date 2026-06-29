# PARENT APP AUDIT — 2026-06-30 (2-bosqich)

> Agent-asosli audit. 16 ta chuqur-tahlil agenti (har feature-soha, 224 fayl) →
> jiddiy topilmalar alohida skeptik agent tomonidan kod bilan **adversarial tasdiqlangan**.
> 32 agent, ~1.8M token. `flutter analyze --fatal-infos` = **0** (lint toza) — bular
> ish-vaqti / mantiq muammolari.
>
> **Holat:** 0 kritik · **43 jiddiy (major)** · 77 o'rta (minor) · 23 mayda (nit).
> Bu hujjat keyingi sessiyalarda tuzatish rejasi — band tugagach `[x]` belgilang.
> (Eski `PARENT_APP_AUDIT.md` — 2026-06-12 audit, alohida hujjat.)

---

## ENG MUHIM 5 ILDIZ-SABAB

Ko'p topilma bir necha umumiy patterndan kelib chiqadi. Ildizni tuzatish o'nlab simptomni yopadi.

### A. "Jo'natdim" deb yolg'on aytish (xato yutiladi → UI muvaffaqiyat ko'rsatadi) — eng katta
Repolar `DioException`ni yutib `false`/`null`/`[]` qaytaradi; UI natijani tekshirmaydi.

- [ ] **A1** Bildirishnoma: unlock qaror xato bo'lsa ham **karta o'chiriladi** — `notifications/presentation/screens/notifications_screen.dart:232-251`
- [ ] **A2** "Rad et"/"Rad etish" backend natijasini e'tiborsiz qoldirib "bajarildi" deydi — `notifications_screen.dart:256-299`
- [ ] **A3** Sessiya bekor qilish xatosi yutiladi, doim "muvaffaqiyat" — `settings/presentation/providers/sessions_provider.dart:28-39`
- [ ] **A4** Rasm so'rovi xato'da "yuborildi" deydi — `photo_request/presentation/providers/photo_request_provider.dart:62-73`
- [ ] **A5** WS refresh paytida tarmoq uzilsa rasm-so'rov ro'yxati **jimgina bo'shaydi** — `photo_request_provider.dart:27-31`
- [ ] **A6** Jadval o'zgartirishlari (toggle/edit/delete) fire-and-forget — xato ko'rinmaydi — `schedules/presentation/screens/schedules_list_screen.dart:189-367`
- [ ] **A7** `getRoutines` xatoni `[]` qiladi → UI "hammasi o'chiq" ko'rinadi — `schedules/data/repositories/backend_routine_repository.dart:52-72`
- [ ] **A8** Fikr-mulohaza inbox xatoni "fikr yo'q" qilib ko'rsatadi (error/retry yo'q) — `feedback/data/repositories/backend_feedback_repository.dart:29-47`
- [ ] **A9** Gamifikatsiya profil xatosi `null` → XP=0 (xatodan farqsiz) — `gamification/data/repositories/backend_gamification_repository.dart:75-87`

> **Yagona fix:** repolar xatoni rethrow qilsin (yoki `Result`/sentinel); UI muvaffaqiyatni tekshirib xato toast + retry ko'rsatsin; refresh xato'da oxirgi yaxshi ro'yxatni saqlasin.

### B. Qattiq yozilgan o'zbekcha matnlar (i18n buzilishi) — ru/en foydalanuvchilar o'zbekcha ko'radi
- [ ] **B1** Joylashuv tarixi UI literallar — `location/presentation/screens/location_map_sheet.dart:114,130,133,201,282-310`
- [ ] **B2** Ilova vaqti `daq/soat` getteri — `app_restrictions/data/models/app_usage.dart:67-74`
- [ ] **B3** Jins yorliqlari `O'g'il/Qiz` — `child_management/data/models/gender.dart:10-17`
- [ ] **B4** Ro'yxatdan o'tish OTP xato xabarlari — `auth/presentation/screens/sign_up_screen.dart:163-166,195-198,245`
- [ ] **B5** "Bildirishnoma sozlamalari" — **butun ekran** hardcoded (i18n import ham yo'q) — `settings/presentation/screens/notification_preferences_screen.dart`
- [ ] **B6** Dashboard ekran-vaqti formati `0 min`/`${h}s $m min` — `dashboard/presentation/screens/dashboard_sections.dart:470-477`
- [ ] **B7** `friendlyError` backend'ning **inglizcha** NestJS xabarini to'g'ridan ko'rsatadi — `core/network/friendly_error.dart:24-27`

### C. `await`'dan keyin `mounted`/`context.mounted` guard yo'q → crash/exception
- [ ] **C1** Support fayl ochish (network download'dan keyin `context`) — `support/presentation/screens/support_chat_bubbles.dart:420-447`
- [ ] **C2** Ruxsat toggle'dan keyin guard'siz `ref.invalidate` — `quick_actions/presentation/screens/permission_apps_screen.dart:52-73`
- [ ] **C3** (minor) `app_limit_modal.dart:310-313`, `notification_preferences_screen.dart:94-106`, `permission_service.dart:55-80`

### D. `autoDispose` qilinmagan provider-family → resurs sızıshi (leak)
- [ ] **D1** `childAddressProvider` autoDispose emas → **jonli-lokatsiya WS streamini butun sessiya ushlaydi** (soket yopilmaydi) — `location/presentation/providers/child_location_provider.dart:113-123`
- [ ] **D2** `childProfileProvider`/`childFeedbackProvider` — har `childId` uchun `StreamController` + WS subscription leak — `gamification/presentation/providers/gamification_provider.dart:10-37`

### E. Widget leak'lari + xavfsiz bo'lmagan JSON castlari (crash)
- [ ] **E1** `OtpInput` `build()` ichida dispose qilinmagan `FocusNode` (har bosishda yangi) — `shared/widgets/otp_input.dart:137-139`
- [ ] **E2** Marquee `AnimationController` matn sig'sa ham abadiy aylanadi — `dashboard/presentation/screens/dashboard_sections.dart:951-957`
- [ ] **E3** (minor) `build()` ichida `TextPainter` dispose qilinmaydi — `dashboard_sections.dart:967-971`
- [ ] **E4** `getEvents()` `as Map` cast — bitta buzuq element **butun tarixni** qulatadi — `geo_zones/data/repositories/backend_geo_zone_repository.dart:83-90` (`parseListSafely` ishlatish)
- [ ] **E5** (minor) Unsafe castlar: `child_location.dart:25-34`, `schedule.dart:210-213` (`d as int`), `telegram_login_screen.dart:82-86`

---

## YAQINDAGI REDIZAYN REGRESSIYALARI (farzand qo'shish — Parvoz)

- [ ] **R1** Har yangi bolada osilib qolgan **"• "** (hudud bo'sh) — `child_management/.../add_child_screen.dart` (region:'') + `children_management_screen.dart:216-218` (shartli qilish)
- [ ] **R2** Tahrirlash rejimida **"qo'shish" sarlavhasi + 3-qadamli wizard** ko'rinadi (chalg'ituvchi) — edit uchun alohida sarlavha + wizard'ni yashirish
- [ ] **R3** Jins yorliqlari i18n (B3 bilan bir xil)
- [ ] **R4** Tahrirda **telefon raqamni o'chirib bo'lmaydi** — bo'sh qiymat `toJson`'dan tushib qoladi — `child_model.dart:288-297`

---

## MA'LUMOT BUG'LARI

- [ ] **F1** Bola ilovani <60s ishlatsa, o'sha ilova **boshqaruv ro'yxatidan yo'qoladi** — `app_restrictions/data/models/app_combined.dart:137-181` (seenPackages'ni `filteredApps`dan qur)
- [ ] **F2** Trend % "kecha"ni sana bilan emas, pozitsiya bilan oladi → noto'g'ri foiz — `app_restrictions/presentation/screens/app_restrictions_screen.dart:149-154`
- [ ] **F3** Geo-zona event tile **hech qachon bola ismini ko'rsatmaydi** — doim "Bola" fallback — `geo_zone_event.dart:62-86` + `geo_zone_event_tile.dart:69-71` (childName'ni ekrandan uzatish)
- [ ] **F4** Geo-zona edit: zona kechiksa **bo'sh default'lar** ko'rinadi (1 marta retry) — `add_edit_geo_zone_screen.dart:151-174` (`ref.listen`'da `_applyZone`)

---

## XAVFSIZLIK / UX (jiddiy)

- [ ] **G1** SOS qo'ng'iroq `launchUrl` guard'siz → dialer yo'q qurilmalarda **crash** — `notifications/presentation/widgets/sos_alert_dialog.dart:70-74`
- [ ] **G2** Video yuklash xatosida **xom Dio xabari** foydalanuvchiga — `video_message/presentation/providers/video_message_provider.dart:183-188` (`friendlyError`)
- [ ] **G3** Sessiya tugatish dialogida **qizil rang noto'g'ri tugmada** ("Yo'q"da; "Ha"da bo'lishi kerak) — `settings/presentation/screens/active_sessions_screen.dart:513-523`
- [ ] **G4** Re-pair tasdiqlash **bir bosishda** (reject esa tasdiq so'raydi) — `pair_requests/presentation/screens/pair_requests_screen.dart:141-205`
- [ ] **G5** Pair-request boshlang'ich fetch `try/catch`'dan tashqarida → offline'da WS auto-recovery o'ladi — `pair_requests/presentation/providers/pair_request_providers.dart:23-49`
- [ ] **G6** (uncertain) Force-update dialog navigator null bo'lsa abadiy bostiriladi — `app.dart:200-228` (qo'shimcha tekshirish kerak)
- [ ] **G7** (minor) Chat media proxy URL'lari autentifikatsiyasiz (IDOR yuzasi) — backend egalik tekshiruvi — `voice_message/data/repositories/backend_voice_message_repository.dart:159-169`

---

## PERFORMANS

- [ ] **P1** `ChildAvatar` `Image.memory`'ni `cacheWidth`'siz to'liq o'lchamda dekod qiladi — `shared/widgets/child_avatar.dart:90-92`
- [ ] **P2** 401-retry **iste'mol qilingan multipart FormData**ni qayta o'ynaydi (yuklamalar buziladi) — `core/network/dio_client.dart:128-134`
- [ ] **P3** Yozish paytida elapsed-timer butun ekranni 1s'da rebuild qiladi (waveform izolyatsiya qilingan, sekund yo'q) — `voice_message/.../voice_chat_screen.dart:225-229`
- [ ] **P4** (minor) `location_map_screen.dart:222-229` — `build()` ichida FCM so'rov side-effect

---

## MUHIM MINORLAR (to'liq ro'yxat audit chiqishida)

- [ ] Tez tap-release → **yetim ovoz yozuvi** to'xtamaydi/yuklanmaydi — `voice_chat_screen.dart:177-239`
- [ ] `AudioPlayerManager` id'ni `setUrl`'dan oldin emit qiladi (flicker) — `audio_player_manager.dart:89-120`
- [ ] ChatHistory cursor client-filtrlangan qatorlarni hisoblaydi — `voice_message_providers.dart:306-357`
- [ ] `deleteZone` DioException'ni yutib soxta xabar qaytaradi — `backend_geo_zone_repository.dart:137-144`
- [ ] Gender enum noma'lum qiymatni `male`'ga default qiladi — `child_model.dart:300-309`
- [ ] Global `onSessionExpired` callback tiklanmasdan ustiga yoziladi — `backend_auth_provider.dart:57-63`
- [ ] `OtpInput` kod to'lganda har bosishda `onCompleted` qayta chaqiradi — `otp_input.dart:84-88`
- [ ] `formatRelativeTime` local now() + UTC timestamp aralashtiradi — `core/utils/formatters.dart:17-38`
- [ ] `compareSemver` pre-release suffiksni e'tiborsiz qoldiradi — `app_version_info.dart:90-107`
- [ ] FCM `getToken()` timeout'siz — init'da osilishi mumkin — `fcm_service.dart:113-142`
- [ ] Noma'lum FCM `type` → `NotificationType.online` ga jim map — `app_notification.dart:187-208`
- [ ] Support biriktirma yuklash default 30s timeout'ga tayanadi — `support_attachment_repository.dart:56-85`

---

## TAVSIYA TARTIBI

| Sessiya | Bandlar | Natija |
|---|---|---|
| 1 | **A1–A9** (yolg'on-muvaffaqiyat) | Foydalanuvchi xatolarni ko'radi, ishonch tiklanadi |
| 2 | **C1–C3, G1, E4–E5** (crash himoya) | Exception/crash yo'qoladi |
| 3 | **D1–D2, E1–E3, P1–P3** (leak + perf) | Xotira/batareya barqaror |
| 4 | **F1–F4** (ma'lumot bug'lari) | Statistika to'g'ri |
| 5 | **R1–R4** (redizayn regressiyalari) | Farzand qo'shish silliq |
| 6 | **B1–B7** (i18n) | ru/en to'liq tarjima |
| 7 | **G2–G7** + tozalash (`ExpandableMap`/`FullScreenMapScreen` ~700 qator o'lik kod o'chirish) | Polish |
